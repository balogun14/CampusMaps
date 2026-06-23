use crate::config::AppConfig;
use crate::ingestion::regional_config::RegionConfig;
use crate::ingestion::tile_builder;
use crate::proto::runit_maps::v1::admin_service_server::AdminService;
use crate::proto::runit_maps::v1::{
    ReloadTilesRequest, ReloadTilesResponse, TileBuildStatus, TileStatusRequest,
    TileStatusResponse,
};
use std::path::Path;
use std::sync::{Arc, Mutex};
use tonic::{async_trait, Request, Response, Status};
use tracing::{error, info};
use uuid::Uuid;

type BuildState = Arc<Mutex<std::collections::HashMap<String, BuildJob>>>;

struct BuildJob {
    status: TileBuildStatus,
    error_message: Option<String>,
    last_build_time: Option<std::time::SystemTime>,
    last_build_duration_secs: Option<f32>,
}

pub struct AdminServiceImpl {
    config: AppConfig,
    build_state: BuildState,
}

impl AdminServiceImpl {
    pub fn new(config: AppConfig) -> Self {
        Self {
            build_state: Arc::new(Mutex::new(std::collections::HashMap::new())),
            config,
        }
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

        // Mark as building
        {
            let mut state = self.build_state.lock().unwrap();
            state.insert(
                inner.region_id.clone(),
                BuildJob {
                    status: TileBuildStatus::Building,
                    error_message: None,
                    last_build_time: None,
                    last_build_duration_secs: None,
                },
            );
        }

        // Spawn background tile build
        let region_id = inner.region_id.clone();
        let job_id_clone = job_id.clone();
        let config = self.config.clone();
        let build_state = self.build_state.clone();

        tokio::spawn(async move {
            info!(
                region = %region_id,
                job = %job_id_clone,
                "Starting background tile build"
            );

            let data_root = Path::new(&config.ingestion.custom_paths_dir)
                .parent()
                .map(|p| p.to_path_buf())
                .unwrap_or_else(|| Path::new("/data").to_path_buf());

            let region = match RegionConfig::from_id(
                &region_id,
                &data_root,
                &config.ingestion.download_base_url,
            ) {
                Ok(r) => r,
                Err(e) => {
                    error!(region = %region_id, error = %e, "Failed to build region config");
                    let mut state = build_state.lock().unwrap();
                    state.insert(
                        region_id.clone(),
                        BuildJob {
                            status: TileBuildStatus::Error,
                            error_message: Some(e.to_string()),
                            last_build_time: None,
                            last_build_duration_secs: None,
                        },
                    );
                    return;
                }
            };

            let osm_data_dir = Path::new(&config.ingestion.osm_data_dir);
            let valhalla_config = Path::new(&config.ingestion.valhalla_config_path);

            let start = std::time::Instant::now();
            let result = tile_builder::rebuild_tiles(&region, osm_data_dir, valhalla_config).await;

            let duration = start.elapsed().as_secs_f32();

            match result {
                Ok(report) => {
                    info!(
                        region = %region_id,
                        job = %job_id_clone,
                        duration_secs = %report.duration_secs,
                        "Background tile build complete"
                    );
                    let mut state = build_state.lock().unwrap();
                    state.insert(
                        region_id.clone(),
                        BuildJob {
                            status: TileBuildStatus::Idle,
                            error_message: None,
                            last_build_time: Some(std::time::SystemTime::now()),
                            last_build_duration_secs: Some(duration),
                        },
                    );
                }
                Err(e) => {
                    error!(
                        region = %region_id,
                        job = %job_id_clone,
                        error = %e,
                        "Background tile build failed"
                    );
                    let mut state = build_state.lock().unwrap();
                    state.insert(
                        region_id.clone(),
                        BuildJob {
                            status: TileBuildStatus::Error,
                            error_message: Some(e.to_string()),
                            last_build_time: None,
                            last_build_duration_secs: Some(duration),
                        },
                    );
                }
            }
        });

        Ok(Response::new(ReloadTilesResponse {
            job_id,
            status: TileBuildStatus::Building.into(),
        }))
    }

    async fn get_tile_status(
        &self,
        request: Request<TileStatusRequest>,
    ) -> Result<Response<TileStatusResponse>, Status> {
        let inner = request.into_inner();
        let state = self.build_state.lock().unwrap();

        let regions = self
            .config
            .ingestion
            .regions
            .iter()
            .map(|r| {
                let job = state.get(r);
                let (status, last_build_time, last_build_duration_secs, error_message) =
                    match job {
                        Some(j) => (
                            j.status,
                            j.last_build_time
                                .map(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                                .flatten()
                                .map(|d| d.as_secs() as u64),
                            j.last_build_duration_secs,
                            j.error_message.clone(),
                        ),
                        None => (TileBuildStatus::Idle, None, None, None),
                    };

                // If a specific region was requested, only return that one
                if !inner.region_id.is_empty() && r != &inner.region_id {
                    return None;
                }

                Some(crate::proto::runit_maps::v1::RegionTileStatus {
                    region_id: r.clone(),
                    status: status.into(),
                    last_build_time,
                    last_build_duration_secs,
                    error_message,
                })
            })
            .flatten()
            .collect();

        Ok(Response::new(TileStatusResponse { regions }))
    }
}
