use anyhow::Result;
use clap::{Parser, Subcommand};
use runit_maps::api::{admin_service::AdminServiceImpl, routing_service::RoutingServiceImpl};
use runit_maps::common::build_state;
use runit_maps::common::telemetry;
use runit_maps::config;
use runit_maps::ingestion::regional_config::RegionConfig;
use runit_maps::ingestion::tile_builder;
use runit_maps::proto::runit_maps::v1::{
    admin_service_server::AdminServiceServer,
    routing_service_server::RoutingServiceServer,
};
use runit_maps::routing::client::ValhallaClient;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use tonic::transport::Server;
use tracing::info;

#[derive(Parser)]
#[command(name = "runit-maps", about = "RunIt Maps — campus routing microservice")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the gRPC routing server
    Serve,
    /// Build Valhalla tiles for a region (one-shot)
    BuildTiles {
        /// Region identifier (e.g. "mit-campus")
        region: String,
        /// Override data directory
        #[arg(long, default_value = "/data")]
        data_dir: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    telemetry::init();
    let cli = Cli::parse();
    let cfg = config::load()?;

    match cli.command.unwrap_or(Commands::Serve) {
        Commands::Serve => run_server(cfg).await,
        Commands::BuildTiles { region, data_dir } => {
            build_tiles(&cfg, &region, &PathBuf::from(data_dir)).await
        }
    }
}

async fn run_server(cfg: config::AppConfig) -> Result<()> {
    let addr: SocketAddr = format!("0.0.0.0:{}", cfg.server.grpc_port).parse()?;
    info!("Starting RunIt Maps gRPC server on {}", addr);

    let valhalla_client = ValhallaClient::new(cfg.valhalla.url.clone());
    let state = build_state::new_build_state();
    let routing_svc = RoutingServiceImpl::new(valhalla_client, cfg.clone(), state.clone());
    let admin_svc = AdminServiceImpl::new(cfg.clone(), state);

    Server::builder()
        .add_service(RoutingServiceServer::new(routing_svc))
        .add_service(AdminServiceServer::new(admin_svc))
        .serve(addr)
        .await?;

    Ok(())
}

async fn build_tiles(cfg: &config::AppConfig, region_id: &str, data_dir: &PathBuf) -> Result<()> {
    info!(region = %region_id, data_dir = %data_dir.display(), "Starting tile build");

    let region = RegionConfig::from_id(region_id, &cfg.ingestion);
    let osm_data_dir = Path::new(&cfg.ingestion.osm_data_dir);
    let valhalla_config = Path::new(&cfg.ingestion.valhalla_config_path);
    let report = tile_builder::rebuild_tiles(&region, osm_data_dir, valhalla_config).await?;

    info!(
        region = %report.region_id,
        duration_secs = %report.duration_secs,
        success = %report.success,
        "Tile build finished"
    );

    if !report.success {
        anyhow::bail!("Tile build failed for region: {}", region_id);
    }

    Ok(())
}
