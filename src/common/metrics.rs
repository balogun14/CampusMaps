use metrics_exporter_prometheus::PrometheusBuilder;
use std::net::SocketAddr;
use tracing::info;

/// Starts the Prometheus metrics HTTP server on the given address.
pub fn init_metrics(addr: SocketAddr) {
    PrometheusBuilder::new()
        .with_http_listener(addr)
        .install()
        .expect("Failed to start Prometheus metrics exporter");

    info!(addr = %addr, "Metrics HTTP endpoint started");
}

/// Metric label keys
pub mod labels {
    pub const REGION: &str = "region";
    pub const COSTING: &str = "costing";
    pub const ERROR_TYPE: &str = "error_type";
}

/// Initialise metric recording at the start of `route()`.
pub fn record_route_request(costing: &str) {
    metrics::counter!("route_requests_total", "costing" => costing.to_string()).increment(1);
}

/// Record Valhalla round-trip duration and outcome.
pub fn record_valhalla_response(duration_secs: f64, success: bool) {
    metrics::histogram!("valhalla_request_duration_seconds").record(duration_secs);

    if !success {
        metrics::counter!("valhalla_errors_total").increment(1);
    }
}

/// Record a tile build outcome.
pub fn record_tile_build(region: &str, duration_secs: f64, success: bool) {
    if success {
        metrics::counter!("tile_builds_total", "region" => region.to_string(), "status" => "success")
            .increment(1);
    } else {
        metrics::counter!("tile_builds_total", "region" => region.to_string(), "status" => "failure")
            .increment(1);
    }
    metrics::histogram!("tile_build_duration_seconds", "region" => region.to_string())
        .record(duration_secs);
}

/// Record a service-level error (validation, Valhalla, internal, etc.).
pub fn record_error(error_type: &str) {
    metrics::counter!("errors_total", "type" => error_type.to_string()).increment(1);
}
