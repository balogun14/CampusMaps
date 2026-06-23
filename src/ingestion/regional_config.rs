use crate::common::error::ServiceError;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Configuration for a single campus/region.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegionConfig {
    /// Unique region identifier, e.g. "mit-campus"
    pub id: String,
    /// Geofabrik region name, e.g. "massachusetts"
    pub osm_region: String,
    /// Full URL for the OSM PBF download
    pub osm_pbf_url: String,
    /// Path to this region's custom GeoJSON paths
    pub custom_paths_file: PathBuf,
    /// Output tile directory for this region
    pub tile_dir: PathBuf,
    /// Whether this region uses the custom campus pedestrian costing
    pub use_campus_costing: bool,
}

impl RegionConfig {
    /// Creates a default config for the Medilag (LUTH) campus area.
    pub fn medilag_campus(data_root: &PathBuf) -> Self {
        Self {
            id: "medilag-campus".to_string(),
            osm_region: "nigeria".to_string(),
            osm_pbf_url: "https://download.geofabrik.de/africa/nigeria-latest.osm.pbf"
                .to_string(),
            custom_paths_file: data_root.join("custom_paths/medilag_campus.geojson"),
            tile_dir: data_root.join("tiles/medilag-campus"),
            use_campus_costing: true,
        }
    }

    /// Build a RegionConfig from a raw region ID string and data directory.
    /// Supports known short names ("mit-campus", "harvard-campus") and fully-qualified IDs.
    pub fn from_id(
        id: &str,
        data_dir: &PathBuf,
        download_base_url: &str,
    ) -> Result<Self, ServiceError> {
        match id {
            "medilag-campus" => Ok(Self::medilag_campus(data_dir)),
            _ => {
                let osm_region = id.split('/').next_back().unwrap_or(id);
                Ok(Self {
                    id: id.to_string(),
                    osm_region: osm_region.to_string(),
                    osm_pbf_url: format!("{}/{}-latest.osm.pbf", download_base_url, osm_region),
                    custom_paths_file: data_dir.join(format!("custom_paths/{}.geojson", id)),
                    tile_dir: data_dir.join(format!("tiles/{}", id)),
                    use_campus_costing: true,
                })
            }
        }
    }

    /// Load all configured regions from the app config.
    pub fn from_app_config(
        config: &crate::config::IngestionConfig,
    ) -> Vec<Self> {
        let data_root = PathBuf::from(&config.custom_paths_dir)
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("/data"));

        config
            .regions
            .iter()
            .map(|id| {
                // Try to match known regions, or create a generic one
                match id.as_str() {
                    "medilag-campus" => Self::medilag_campus(&data_root),
                    _ => Self {
                        id: id.clone(),
                        osm_region: id.clone(),
                        osm_pbf_url: format!(
                            "{}/{}-latest.osm.pbf",
                            config.download_base_url, id
                        ),
                        custom_paths_file: data_root.join(format!("custom_paths/{}.geojson", id)),
                        tile_dir: data_root.join(format!("tiles/{}", id)),
                        use_campus_costing: true,
                    },
                }
            })
            .collect()
    }
}
