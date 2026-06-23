use crate::routing::client::ValhallaClient;
use crate::routing::response_parser::parse_valhalla_response;
use crate::routing::validator::validate_route_request;
use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::post,
    Json, Router,
};
use serde::Deserialize;
use std::collections::HashSet;
use std::net::SocketAddr;
use std::sync::Arc;
use tracing::info;

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RouteRequestJson {
    pub origin: LatLngJson,
    pub destination: LatLngJson,
    #[serde(default = "default_costing")]
    pub costing: String,
    #[serde(default)]
    pub avoid_stairs: bool,
    #[serde(default = "default_walking_speed")]
    pub walking_speed_kmh: f64,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LatLngJson {
    pub lat: f64,
    pub lng: f64,
}

fn default_costing() -> String {
    "pedestrian".to_string()
}

fn default_walking_speed() -> f64 {
    5.0
}

#[derive(Clone)]
pub struct RestState {
    pub valhalla_client: ValhallaClient,
    pub campus_path_names: HashSet<String>,
}

pub fn build_router(state: RestState) -> Router {
    Router::new()
        .route("/v1/route", post(handle_route))
        .layer(
            tower_http::cors::CorsLayer::permissive(),
        )
        .with_state(Arc::new(state))
}

async fn handle_route(
    State(state): State<Arc<RestState>>,
    Json(req): Json<RouteRequestJson>,
) -> impl IntoResponse {
    // Build proto-compatible request for validation + parsing
    let proto_req = crate::proto::runit_maps::v1::RouteRequest {
        origin: Some(crate::proto::runit_maps::v1::LatLng {
            lat: req.origin.lat,
            lng: req.origin.lng,
        }),
        destination: Some(crate::proto::runit_maps::v1::LatLng {
            lat: req.destination.lat,
            lng: req.destination.lng,
        }),
        costing: match req.costing.as_str() {
            "campus_pedestrian" => 4,
            "auto" => 1,
            "bicycle" => 3,
            _ => 2,
        },
        avoid_stairs: req.avoid_stairs,
        walking_speed_kmh: req.walking_speed_kmh,
        ..Default::default()
    };

    if let Err(e) = validate_route_request(&proto_req) {
        return (StatusCode::BAD_REQUEST, Json(serde_json::json!({
            "error": e.to_string()
        })));
    }

    // Build Valhalla JSON request
    let mut locations = Vec::new();
    locations.push(serde_json::json!({
        "lat": req.origin.lat, "lon": req.origin.lng, "type": "break"
    }));
    locations.push(serde_json::json!({
        "lat": req.destination.lat, "lon": req.destination.lng, "type": "break"
    }));

    let costing = match req.costing.as_str() {
        "campus_pedestrian" => "campus_pedestrian",
        "auto" => "auto",
        "bicycle" => "bicycle",
        _ => "pedestrian",
    };

    let mut costing_options = serde_json::json!({});
    if req.costing == "campus_pedestrian" {
        costing_options = serde_json::json!({
            "campus_pedestrian": {
                "walking_speed": req.walking_speed_kmh.max(1.0),
                "use_campus_paths": 0.9,
                "avoid_stairs": if req.avoid_stairs { 0.5 } else { 0.0 }
            }
        });
    }

    let valhalla_req = serde_json::json!({
        "locations": locations,
        "costing": costing,
        "costing_options": costing_options,
        "directions_options": { "units": "kilometers", "language": "en-US" },
        "id": format!("rest-{}", std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis())
            .unwrap_or(0))
    });

    // Call Valhalla
    let raw = match state.valhalla_client.route(&valhalla_req).await {
        Ok(r) => r,
        Err(e) => {
            return (StatusCode::BAD_GATEWAY, Json(serde_json::json!({
                "error": format!("Valhalla error: {}", e)
            })));
        }
    };

    // Parse into proto response
    let proto_resp = match parse_valhalla_response(&raw, &proto_req, &state.campus_path_names) {
        Ok(r) => r,
        Err(e) => {
            return (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({
                "error": format!("Parse error: {}", e)
            })));
        }
    };

    (StatusCode::OK, Json(serde_json::json!({
        "encodedPolyline": proto_resp.encoded_polyline,
        "summary": {
            "distanceMeters": proto_resp.summary.as_ref().map(|s| s.distance_meters).unwrap_or(0.0),
            "durationSeconds": proto_resp.summary.as_ref().map(|s| s.duration_seconds).unwrap_or(0.0),
            "distanceKm": proto_resp.summary.as_ref().map(|s| s.distance_km).unwrap_or(0.0),
            "durationFormatted": proto_resp.summary.as_ref().map(|s| s.duration_formatted.clone()).unwrap_or_default(),
        },
        "steps": proto_resp.steps.iter().map(|s| serde_json::json!({
            "stepNumber": s.step_number,
            "instruction": s.instruction,
            "streetName": s.street_name,
            "startLocation": {
                "lat": s.start_location.as_ref().map(|l| l.lat).unwrap_or(0.0),
                "lng": s.start_location.as_ref().map(|l| l.lng).unwrap_or(0.0),
            },
            "distanceMeters": s.distance_meters,
            "durationSeconds": s.duration_seconds,
            "direction": s.direction,
            "isCustomPath": s.is_custom_path,
        })).collect::<Vec<_>>(),
    })))
}

/// Starts the REST HTTP server on the given address.
pub async fn start_rest_server(
    addr: SocketAddr,
    valhalla_client: ValhallaClient,
    campus_path_names: HashSet<String>,
) {
    info!(addr = %addr, "Starting REST API server");

    let state = RestState { valhalla_client, campus_path_names };
    let app = build_router(state);

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("Failed to bind REST server");

    axum::serve(listener, app)
        .await
        .expect("REST server failed");
}
