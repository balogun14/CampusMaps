use crate::common::error::ServiceError;
use crate::ingestion::geojson;
use crate::ingestion::osm;
use crate::ingestion::regional_config::RegionConfig;
use std::path::Path;
use std::process::Command;
use tracing::info;

/// Result of a tile build operation.
pub struct BuildReport {
    pub region_id: String,
    pub tile_count: u64,
    pub edge_count: u64,
    pub duration_secs: f64,
    pub success: bool,
}

/// Orchestrates the full tile build pipeline for a single region.
///
/// # Arguments
/// * `region` - Region configuration (tile_dir, custom_paths_file, etc.)
/// * `osm_data_dir` - Directory where downloaded OSM PBF files are cached
/// * `valhalla_config_path` - Path to Valhalla's config JSON (controls tile output dir)
pub async fn rebuild_tiles(
    region: &RegionConfig,
    osm_data_dir: &Path,
    valhalla_config_path: &Path,
) -> Result<BuildReport, ServiceError> {
    let start = std::time::Instant::now();
    let region_id = region.id.clone();
    info!(region = %region_id, "Starting tile rebuild");

    // Step 1: Ensure directories exist
    std::fs::create_dir_all(&region.tile_dir)?;
    std::fs::create_dir_all(osm_data_dir)?;

    // Step 2: Download OSM PBF to the shared osm_data_dir
    let osm_path = osm_data_dir.join(format!("{}.osm.pbf", region.osm_region));
    osm::download_osm_pbf(&region.osm_pbf_url, &osm_path).await?;

    // Step 3: Convert GeoJSON to OSM XML (if custom paths exist)
    let merged_osm_path = region.tile_dir.join("merged.osm.pbf");
    if region.custom_paths_file.exists() {
        info!(
            "Found custom paths at {:?}, converting to OSM XML",
            region.custom_paths_file
        );

        let collection = geojson::parse_geojson(&region.custom_paths_file)?;
        let osm_xml = geojson::collection_to_osm_xml(&collection);

        let custom_osm_path = region.tile_dir.join("custom_paths.osm");
        tokio::fs::write(&custom_osm_path, &osm_xml).await?;

        // Step 4: Merge OSM PBF + custom OSM XML using osmium
        merge_osm_files(&osm_path, &custom_osm_path, &merged_osm_path)?;
    } else {
        info!("No custom paths found, using OSM PBF directly");
        std::fs::copy(&osm_path, &merged_osm_path)?;
    }

    // Step 5: Run Valhalla tile builder
    info!("Running Valhalla tile builder");
    let output = Command::new("valhalla_build_tiles")
        .arg("-c")
        .arg(valhalla_config_path)
        .arg(&merged_osm_path)
        .output()
        .map_err(|e| {
            ServiceError::TileBuild(format!("Failed to execute valhalla_build_tiles: {}", e))
        })?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(ServiceError::TileBuild(format!(
            "valhalla_build_tiles failed: {}",
            stderr.trim()
        )));
    }

    let duration = start.elapsed().as_secs_f64();
    info!(region = %region_id, duration_secs = %duration, "Tile rebuild complete");

    Ok(BuildReport {
        region_id,
        tile_count: 0, // TODO: count actual tiles
        edge_count: 0,
        duration_secs: duration,
        success: true,
    })
}

/// Merges an OSM PBF file with an OSM XML file using the `osmium` tool.
fn merge_osm_files(pbf_path: &Path, xml_path: &Path, output_path: &Path) -> Result<(), ServiceError> {
    let output = Command::new("osmium")
        .arg("merge")
        .arg(pbf_path)
        .arg(xml_path)
        .arg("-o")
        .arg(output_path)
        .output()
        .map_err(|e| {
            ServiceError::TileBuild(format!("Failed to run osmium merge: {}", e))
        })?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(ServiceError::TileBuild(format!(
            "osmium merge failed: {}",
            stderr.trim()
        )));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    /// Validates the full GeoJSON → OSM XML conversion pipeline
    /// without external dependencies (osmium, Valhalla).
    #[test]
    fn test_ingestion_pipeline_smoke() {
        let dir = std::env::temp_dir().join("runit-smoke-test");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();

        // Create sample GeoJSON
        let geojson = r#"{
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {
                    "name": "Test Path",
                    "campus_id": "medilag",
                    "surface": "paved",
                    "lit": "yes",
                    "wheelchair": "yes"
                },
                "geometry": {
                    "type": "LineString",
                    "coordinates": [[3.3515, 6.5135], [3.3510, 6.5145], [3.3490, 6.5165]]
                }
            }, {
                "type": "Feature",
                "properties": {
                    "name": "Stairway",
                    "campus_id": "medilag",
                    "highway": "steps",
                    "wheelchair": "no"
                },
                "geometry": {
                    "type": "LineString",
                    "coordinates": [[3.3492, 6.5160], [3.3495, 6.5155]]
                }
            }]
        }"#;

        let geojson_path = dir.join("test_paths.geojson");
        std::fs::write(&geojson_path, geojson).unwrap();

        // Parse GeoJSON
        let collection = crate::ingestion::geojson::parse_geojson(&geojson_path).unwrap();
        assert_eq!(collection.features.len(), 2);

        // Convert to OSM XML
        let xml = crate::ingestion::geojson::collection_to_osm_xml(&collection);

        // Validate XML structure
        assert!(xml.starts_with(r#"<?xml version="1.0" encoding="UTF-8"?>"#));
        assert!(xml.contains("<osm"));
        assert!(xml.contains("</osm>"));
        assert!(xml.contains("<node id=\"2000000000\""));
        assert!(xml.contains("<node id=\"2000000001\""));
        assert!(xml.contains("<way id=\"1000000000\""));
        assert!(xml.contains("<way id=\"1000000001\""));

        // Validate tags
        assert!(xml.contains("<tag k=\"campus_id\" v=\"medilag\"/>"));
        assert!(xml.contains("<tag k=\"highway\" v=\"path\"/>"));
        assert!(xml.contains("<tag k=\"highway\" v=\"steps\"/>"));
        assert!(xml.contains("<tag k=\"foot\" v=\"designated\"/>"));
        assert!(xml.contains("<tag k=\"wheelchair\" v=\"no\"/>"));

        // Write to OSM XML file and verify it's valid
        let osm_path = dir.join("test_output.osm");
        std::fs::write(&osm_path, &xml).unwrap();
        let written = std::fs::read_to_string(&osm_path).unwrap();
        assert_eq!(written, xml);

        // Cleanup
        std::fs::remove_dir_all(&dir).unwrap();
    }

    /// Tests that the pipeline correctly handles a GeoJSON with no custom
    /// properties (falls back to defaults: highway=path, foot=designated).
    #[test]
    fn test_minimal_geojson_feature() {
        let geojson = r#"{
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {
                    "name": "Minimal",
                    "campus_id": "medilag"
                },
                "geometry": {
                    "type": "LineString",
                    "coordinates": [[3.35, 6.51], [3.36, 6.52]]
                }
            }]
        }"#;

        let dir = std::env::temp_dir().join("runit-minimal-test");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();

        let path = dir.join("minimal.geojson");
        std::fs::write(&path, geojson).unwrap();

        let collection = crate::ingestion::geojson::parse_geojson(&path).unwrap();
        let xml = crate::ingestion::geojson::collection_to_osm_xml(&collection);

        // Default tags should be applied
        assert!(xml.contains("<tag k=\"highway\" v=\"path\"/>"));
        assert!(xml.contains("<tag k=\"foot\" v=\"designated\"/>"));
        assert!(xml.contains("<tag k=\"name\" v=\"Minimal\"/>"));

        std::fs::remove_dir_all(&dir).unwrap();
    }

    /// Integration test that requires osmium and Valhalla.
    /// Run with: RUNIT_INTEGRATION_TEST=1 cargo test
    #[tokio::test]
    async fn test_rebuild_tiles_no_custom_paths() {
        if std::env::var("RUNIT_INTEGRATION_TEST").is_err() {
            return;
        }

        let region = RegionConfig {
            id: "test".to_string(),
            osm_region: "test".to_string(),
            osm_pbf_url: "https://download.geofabrik.de/africa/nigeria-latest.osm.pbf"
                .to_string(),
            custom_paths_file: PathBuf::from("/nonexistent.geojson"),
            tile_dir: PathBuf::from("/tmp/runit-test-tiles"),
            use_campus_costing: true,
        };

        let result = rebuild_tiles(
            &region,
            Path::new("/tmp/runit-test-osm"),
            Path::new("/config/valhalla.json"),
        )
        .await;
        // Should fail because we don't have the real setup, but shouldn't panic
        assert!(result.is_err());
    }
}
