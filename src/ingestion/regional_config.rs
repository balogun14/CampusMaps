use crate::config::RegionDefinition;
use std::path::PathBuf;

/// Resolved configuration for a single campus/region.
#[derive(Debug, Clone)]
pub struct RegionConfig {
    pub id: String,
    pub osm_region: String,
    pub osm_pbf_url: String,
    pub custom_paths_file: PathBuf,
    pub tile_dir: PathBuf,
    pub use_campus_costing: bool,
}

impl RegionConfig {
    /// Build a RegionConfig from a raw region ID by looking it up in the
    /// app configuration. Falls back to a generic definition if not found.
    pub fn from_id(
        id: &str,
        cfg: &crate::config::IngestionConfig,
    ) -> Self {
        // Look up in configured regions first
        if let Some(def) = cfg.regions.iter().find(|r| r.id == id) {
            return Self::from_definition(def, cfg);
        }

        // Fallback: build a generic region from the ID
        let osm_region = id.split('/').next_back().unwrap_or(id);
        let custom_dir = PathBuf::from(&cfg.custom_paths_dir);
        let tile_dir = PathBuf::from(&cfg.tile_dir);
        Self {
            id: id.to_string(),
            osm_region: osm_region.to_string(),
            osm_pbf_url: format!("{}/{}-latest.osm.pbf", cfg.download_base_url, osm_region),
            custom_paths_file: custom_dir.join(format!("{}.geojson", id)),
            tile_dir: tile_dir.join(id),
            use_campus_costing: true,
        }
    }

    /// Load all configured regions from the app config.
    pub fn from_app_config(
        config: &crate::config::IngestionConfig,
    ) -> Vec<Self> {
        config
            .regions
            .iter()
            .map(|def| Self::from_definition(def, config))
            .collect()
    }

    fn from_definition(def: &RegionDefinition, cfg: &crate::config::IngestionConfig) -> Self {
        let custom_dir = PathBuf::from(&cfg.custom_paths_dir);
        let tile_dir = PathBuf::from(&cfg.tile_dir);
        Self {
            id: def.id.clone(),
            osm_region: def.osm_region.clone(),
            osm_pbf_url: if def.osm_pbf_url.is_empty() {
                format!("{}/{}-latest.osm.pbf", cfg.download_base_url, def.osm_region)
            } else {
                def.osm_pbf_url.clone()
            },
            custom_paths_file: custom_dir.join(&def.custom_paths_file),
            tile_dir: if def.tile_dir.is_empty() {
                tile_dir.join(&def.id)
            } else {
                PathBuf::from(&def.tile_dir)
            },
            use_campus_costing: def.use_campus_costing,
        }
    }
}
