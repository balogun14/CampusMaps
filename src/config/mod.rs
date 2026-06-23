use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    pub server: ServerConfig,
    pub valhalla: ValhallaConfig,
    pub ingestion: IngestionConfig,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ServerConfig {
    pub grpc_port: u16,
    pub max_request_size_mb: u32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ValhallaConfig {
    pub url: String,
    pub timeout_seconds: u64,
    pub max_alternatives: u32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct IngestionConfig {
    pub download_base_url: String,
    pub tile_dir: String,
    pub osm_data_dir: String,
    pub custom_paths_dir: String,
    pub regions: Vec<String>,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            server: ServerConfig {
                grpc_port: 50051,
                max_request_size_mb: 4,
            },
            valhalla: ValhallaConfig {
                url: "http://localhost:8002".to_string(),
                timeout_seconds: 10,
                max_alternatives: 3,
            },
            ingestion: IngestionConfig {
                download_base_url: "https://download.geofabrik.de/north-america/us"
                    .to_string(),
                tile_dir: "/data/tiles".to_string(),
                osm_data_dir: "/data/osm".to_string(),
                custom_paths_dir: "/data/custom_paths".to_string(),
                regions: vec!["mit-campus".to_string()],
            },
        }
    }
}

impl AppConfig {
    pub fn from_env() -> Result<Self> {
        let mut cfg = config::Config::builder()
            .set_default("server.grpc_port", "50051")?
            .set_default("valhalla.url", "http://localhost:8002")?
            .set_default("valhalla.timeout_seconds", "10")?
            .set_default("valhalla.max_alternatives", "3")?
            .set_default("ingestion.download_base_url", "https://download.geofabrik.de/north-america/us")?
            .add_source(config::File::with_name("config/default").required(false))
            .add_source(
                config::Environment::with_prefix("RUNIT")
                    .separator("__")
                    .try_parsing(true),
            );

        // Override with VALHALLA_URL directly for convenience
        if let Ok(url) = std::env::var("VALHALLA_URL") {
            cfg = cfg.set_override("valhalla.url", url)?;
        }
        if let Ok(port) = std::env::var("GRPC_PORT") {
            cfg = cfg.set_override("server.grpc_port", port)?;
        }

        cfg.build()?
            .try_deserialize()
            .context("Failed to deserialize config")
    }
}

pub fn load() -> Result<AppConfig> {
    AppConfig::from_env()
}
