use anyhow::Result;
use runit_maps::api::{routing_service::RoutingServiceImpl, admin_service::AdminServiceImpl};
use runit_maps::common::telemetry;
use runit_maps::config;
use runit_maps::proto::runit_maps::v1::{
    admin_service_server::AdminServiceServer,
    routing_service_server::RoutingServiceServer,
};
use runit_maps::routing::client::ValhallaClient;
use std::net::SocketAddr;
use tonic::transport::Server;
use tracing::info;

#[tokio::main]
async fn main() -> Result<()> {
    telemetry::init();
    let cfg = config::load()?;

    let addr: SocketAddr = format!("0.0.0.0:{}", cfg.server.grpc_port).parse()?;
    info!("Starting RunIt Maps gRPC server on {}", addr);

    let valhalla_client = ValhallaClient::new(cfg.valhalla.url.clone());
    let routing_svc = RoutingServiceImpl::new(valhalla_client, cfg.clone());
    let admin_svc = AdminServiceImpl::new(cfg.clone());

    Server::builder()
        .add_service(RoutingServiceServer::new(routing_svc))
        .add_service(AdminServiceServer::new(admin_svc))
        .serve(addr)
        .await?;

    Ok(())
}
