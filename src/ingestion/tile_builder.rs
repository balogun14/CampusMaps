use crate::common::error::ServiceError;
use crate::ingestion::geojson;
use crate::ingestion::osm;
use crate::ingestion::regional_config::RegionConfig;
use std::path::Path;
use std::process::Command;
use tracing::{error, info};

/// Result of a tile build operation.
pub struct BuildReport {
    pub region_id: String,
    pub tile_count: u64,
    pub edge_count: u64,
    pub duration_secs: f64,
    pub success: bool,
}

/// Orchestrates the full tile build pipeline for a single region.
pub async fn rebuild_tiles(region: &RegionConfig) -> Result<BuildReport, ServiceError> {
    let start = std::time::Instant::now();
    let region_id = region.id.clone();
    info!(region = %region_id, "Starting tile rebuild");

    // Step 1: Ensure tile directory exists
    let tile_dir = &region.tile_dir;
    std::fs::create_dir_all(tile_dir)?;

    // Step 2: Download OSM PBF
    let osm_path = tile_dir.parent().unwrap_or(Path::new("/data/osm"))
        .join(format!("{}.osm.pbf", region.osm_region));
    
    osm::download_osm_pbf(&region.osm_pbf_url, &osm_path).await?;

    // Step 3: Convert GeoJSON to OSM XML (if custom paths exist)
    let merged_osm_path = tile_dir.join("merged.osm.pbf");
    if region.custom_paths_file.exists() {
        info!("Found custom paths at {:?}, converting to OSM XML", region.custom_paths_file);
        
        let collection = geojson::parse_geojson(&region.custom_paths_file)?;
        let osm_xml = geojson::collection_to_osm_xml(&collection);
        
        let custom_osm_path = tile_dir.join("custom_paths.osm");
        tokio::fs::write(&custom_osm_path, &osm_xml).await?;

        // Step 4: Merge OSM PBF + custom OSM XML using osmium
        merge_osm_files(&osm_path, &custom_osm_path, &merged_osm_path)?;
    } else {
        info!("No custom paths found, using OSM PBF directly");
        std::fs::copy(&osm_path, &merged_osm_path)?;
    }

    // Step 5: Run Valhalla tile builder
    info!("Running Valhalla tile builder");
    let status = Command::new("valhalla_build_tiles")
        .arg("-c")
        .arg("/config/valhalla.json")
        .arg(&merged_osm_path)
        .status()
        .map_err(|e| {
            ServiceError::TileBuild(format!("Failed to execute valhalla_build_tiles: {}", e))
        })?;

    if !status.success() {
        return Err(ServiceError::TileBuild(
            "valhalla_build_tiles exited with non-zero status".into(),
        ));
    }

    let duration = start.elapsed().as_secs_f64();
    info!(region = %region_id, duration_secs = %duration, "Tile rebuild complete");

    Ok(BuildReport {
        region_id,
        tile_count: 0,  // TODO: count actual tiles
        edge_count: 0,
        duration_secs: duration,
        success: true,
    })
}

/// Merges an OSM PBF file with an OSM XML file using the `osmium` tool.
fn merge_osm_files(pbf_path: &Path, xml_path: &Path, output_path: &Path) -> Result<(), ServiceError> {
    let status = Command::new("osmium")
        .arg("merge")
        .arg(pbf_path)
        .arg(xml_path)
        .arg("-o")
        .arg(output_path)
        .status()
        .map_err(|e| {
            ServiceError::TileBuild(format!("Failed to run osmium merge: {}", e))
        })?;

    if !status.success() {
        return Err(ServiceError::TileBuild(
            "osmium merge exited with non-zero status".into(),
        ));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[tokio::test]
    async fn test_rebuild_tiles_no_custom_paths() {
        // This test requires Valhalla and OSM files to be present, so it's a no-op
        // unless the environment variable RUNIT_INTEGRATION_TEST is set.
        if std::env::var("RUNIT_INTEGRATION_TEST").is_err() {
            return;
        }

        let region = RegionConfig {
            id: "test".to_string(),
            osm_region: "test".to_string(),
            osm_pbf_url: "https://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf"
                .to_string(),
            custom_paths_file: PathBuf::from("/nonexistent.geojson"),
            tile_dir: PathBuf::from("/tmp/runit-test-tiles"),
            use_campus_costing: true,
        };

        let result = rebuild_tiles(&region).await;
        // Should fail because we don't have the real setup, but shouldn't panic
        assert!(result.is_err());
    }
}
