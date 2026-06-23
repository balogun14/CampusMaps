use crate::common::build_state::BuildState;
use crate::common::error::ServiceError;
use crate::config::AppConfig;
use crate::proto::runit_maps::v1::routing_service_server::RoutingService;
use crate::proto::runit_maps::v1::{
    HealthRequest, HealthResponse, RouteRequest, RouteResponse,
};
use crate::routing::client::ValhallaClient;
use crate::routing::response_parser::parse_valhalla_response;
use crate::routing::validator::validate_route_request;
use std::time::SystemTime;
use tonic::{async_trait, Request, Response, Status};
use tracing::info;

pub struct RoutingServiceImpl {
    valhalla_client: ValhallaClient,
    config: AppConfig,
    build_state: BuildState,
}

impl RoutingServiceImpl {
    pub fn new(valhalla_client: ValhallaClient, config: AppConfig, build_state: BuildState) -> Self {
        Self {
            valhalla_client,
            config,
            build_state,
        }
    }

    fn build_valhalla_request(
        &self,
        req: &RouteRequest,
    ) -> Result<serde_json::Value, ServiceError> {
        let mut locations = Vec::new();
        if let Some(origin) = &req.origin {
            locations.push(serde_json::json!({
                "lat": origin.lat,
                "lon": origin.lng,
                "type": "break"
            }));
        }
        if let Some(dest) = &req.destination {
            locations.push(serde_json::json!({
                "lat": dest.lat,
                "lon": dest.lng,
                "type": "break"
            }));
        }

        // Map proto costing to Valhalla costing string
        let costing = match req.costing() {
            crate::proto::runit_maps::v1::Costing::Auto => "auto",
            crate::proto::runit_maps::v1::Costing::Pedestrian => "pedestrian",
            crate::proto::runit_maps::v1::Costing::Bicycle => "bicycle",
            crate::proto::runit_maps::v1::Costing::CampusPedestrian => "campus_pedestrian",
            _ => "pedestrian",
        };

        let mut costing_options = serde_json::json!({});

        // Add campus_pedestrian specific options
        if req.costing() == crate::proto::runit_maps::v1::Costing::CampusPedestrian {
            costing_options = serde_json::json!({
                "campus_pedestrian": {
                    "walking_speed": req.walking_speed_kmh.max(1.0),
                    "use_campus_paths": 0.9,
                    "avoid_stairs": if req.avoid_stairs { 0.5 } else { 0.0 }
                }
            });
        }

        let units = match req.units() {
            crate::proto::runit_maps::v1::Units::Imperial => "miles",
            _ => "kilometers",
        };
Ok(serde_json::json!({
     "locations": locations,
     "costing": costing,
     "costing_options": costing_options,

     "directions_options": {
         "units": units,
         "language": "en-US"
     },
     "campus_id": req.campus_id,
     "include_steps": req.include_steps,
     "waypoints": req.waypoints.iter().map(|latlng| {
         serde_json::json!({
             "lat": latlng.lat,
             "lng": latlng.lng
         })
     }).collect::<Vec<_>>(),
     "id": format!("runit-{}", std::time::SystemTime::now()
         .duration_since(std::time::UNIX_EPOCH)
         .map(|d| d.as_millis())
         .unwrap_or(0))
 }))
    }
}

#[async_trait]
impl RoutingService for RoutingServiceImpl {
    async fn route(
        &self,
        request: Request<RouteRequest>,
    ) -> Result<Response<RouteResponse>, Status> {
        let inner = request.into_inner();
        info!(
            origin = ?inner.origin,
            destination = ?inner.destination,
            "Route request received"
        );

        // Validate
        validate_route_request(&inner)?;

        // Build Valhalla request
        let valhalla_req = self
            .build_valhalla_request(&inner)
            .map_err(|e| Status::internal(e.to_string()))?;

        // Call Valhalla HTTP API
        let raw_response = self
            .valhalla_client
            .route(&valhalla_req)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        // Parse Valhalla response into our proto
        let response = parse_valhalla_response(&raw_response, &inner)?;

        Ok(Response::new(response))
    }

    async fn health_check(
        &self,
        _request: Request<HealthRequest>,
    ) -> Result<Response<HealthResponse>, Status> {
        let valhalla_connected = self
            .valhalla_client
            .health_check()
            .await
            .is_ok();

        // Find the most recent tile build across all regions
        let state = self.build_state.lock().unwrap();
        let tiles_last_updated = state
            .values()
            .filter_map(|j| j.last_build_time)
            .max()
            .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);

        Ok(Response::new(HealthResponse {
            valhalla_connected,
            tiles_last_updated,
            service_version: env!("CARGO_PKG_VERSION").to_string(),
            regions: self.config.ingestion.regions.iter().map(|r| r.id.clone()).collect(),
        }))
    }
}
