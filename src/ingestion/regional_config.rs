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
    /// Creates a default config for the MIT campus area.
    pub fn mit_campus(data_root: &PathBuf) -> Self {
        Self {
            id: "mit-campus".to_string(),
            osm_region: "massachusetts".to_string(),
            osm_pbf_url: "https://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf"
                .to_string(),
            custom_paths_file: data_root.join("custom_paths/mit_campus.geojson"),
            tile_dir: data_root.join("tiles/mit-campus"),
            use_campus_costing: true,
        }
    }

    /// Creates a default config for the Harvard campus area.
    pub fn harvard_campus(data_root: &PathBuf) -> Self {
        Self {
            id: "harvard-campus".to_string(),
            osm_region: "massachusetts".to_string(),
            osm_pbf_url: "https://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf"
                .to_string(),
            custom_paths_file: data_root.join("custom_paths/harvard_campus.geojson"),
            tile_dir: data_root.join("tiles/harvard-campus"),
            use_campus_costing: true,
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
                    "mit-campus" => Self::mit_campus(&data_root),
                    "harvard-campus" => Self::harvard_campus(&data_root),
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
