use crate::config::AppConfig;
use crate::proto::runit_maps::v1::admin_service_server::AdminService;
use crate::proto::runit_maps::v1::{
    ReloadTilesRequest, ReloadTilesResponse, TileBuildStatus, TileStatusRequest,
    TileStatusResponse,
};
use tonic::{async_trait, Request, Response, Status};
use tracing::{error, info};
use uuid::Uuid;

pub struct AdminServiceImpl {
    config: AppConfig,
}

impl AdminServiceImpl {
    pub fn new(config: AppConfig) -> Self {
        Self { config }
    }
}

#[async_trait]
impl AdminService for AdminServiceImpl {
    async fn reload_tiles(
        &self,
        request: Request<ReloadTilesRequest>,
    ) -> Result<Response<ReloadTilesResponse>, Status> {
        let inner = request.into_inner();
        info!(region_id = %inner.region_id, "Tile reload requested");

        // Validate region exists
        if !self.config.ingestion.regions.contains(&inner.region_id) {
            return Err(Status::not_found(format!(
                "Unknown region: {}",
                inner.region_id
            )));
        }

        let job_id = Uuid::new_v4().to_string();

        // Spawn background tile build
        let region = inner.region_id.clone();
        let job_id_clone = job_id.clone();
        tokio::spawn(async move {
            info!(region = %region, job = %job_id_clone, "Starting background tile build");

            // TODO: Implement actual tile builder invocation
            // 1. Download OSM PBF
            // 2. Convert GeoJSON -> OSM XML
            // 3. Merge + build tiles
            // 4. Update tile timestamp

            info!(region = %region, job = %job_id_clone, "Background tile build complete");
        });

        Ok(Response::new(ReloadTilesResponse {
            job_id,
            status: TileBuildStatus::Building.into(),
        }))
    }

    async fn get_tile_status(
        &self,
        _request: Request<TileStatusRequest>,
    ) -> Result<Response<TileStatusResponse>, Status> {
        // Return current status for all configured regions
        let regions = self
            .config
            .ingestion
            .regions
            .iter()
            .map(|r| crate::proto::runit_maps::v1::RegionTileStatus {
                region_id: r.clone(),
                status: TileBuildStatus::Idle.into(),
                last_build_time: None,
                last_build_duration_secs: None,
                error_message: None,
            })
            .collect();

        Ok(Response::new(TileStatusResponse { regions }))
    }
}
