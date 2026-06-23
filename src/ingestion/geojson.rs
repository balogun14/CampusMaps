use crate::common::error::ServiceError;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::Path;

/// Represents a GeoJSON Feature with LineString geometry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoJsonFeature {
    #[serde(rename = "type")]
    pub feature_type: String,
    pub properties: serde_json::Value,
    pub geometry: GeoJsonGeometry,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoJsonGeometry {
    #[serde(rename = "type")]
    pub geometry_type: String,
    pub coordinates: Vec<Vec<f64>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoJsonFeatureCollection {
    #[serde(rename = "type")]
    pub collection_type: String,
    pub features: Vec<GeoJsonFeature>,
}

/// Parses a GeoJSON file containing campus path LineStrings.
pub fn parse_geojson(path: &Path) -> Result<GeoJsonFeatureCollection, ServiceError> {
    let content = std::fs::read_to_string(path)?;
    let collection: GeoJsonFeatureCollection = serde_json::from_str(&content)?;
    Ok(collection)
}

/// Converts a GeoJSON Feature into an OSM XML representation.
/// This produces a string that can be merged with Valhalla's tile builder.
pub fn feature_to_osm_xml(
    feature: &GeoJsonFeature,
    way_id_offset: u64,
    node_id_offset: u64,
) -> String {
    let mut xml = String::new();
    let mut node_id = node_id_offset;

    // Create nodes from coordinates
    let mut nd_refs = Vec::new();
    for coord in &feature.geometry.coordinates {
        if coord.len() >= 2 {
            let lat = coord[1];
            let lon = coord[0];
            xml.push_str(&format!(
                r#"  <node id="{}" lat="{}" lon="{}" version="1" visible="true"/>"#,
                node_id, lat, lon
            ));
            xml.push('\n');
            nd_refs.push(node_id);
            node_id += 1;
        }
    }

    // Create the way with node references
    let way_id = way_id_offset;
    xml.push_str(&format!(
        r#"  <way id="{}" version="1" visible="true">"#,
        way_id
    ));
    xml.push('\n');

    for nd in &nd_refs {
        xml.push_str(&format!("    <nd ref=\"{}\"/>\n", nd));
    }

    // Copy properties from GeoJSON as OSM tags
    if let Some(obj) = feature.properties.as_object() {
        for (key, value) in obj {
            let val_str = match value {
                serde_json::Value::String(s) => s.clone(),
                serde_json::Value::Number(n) => n.to_string(),
                serde_json::Value::Bool(b) => b.to_string(),
                _ => continue,
            };
            xml.push_str(&format!(
                r#"    <tag k="{}" v="{}"/>"#,
                key, val_str
            ));
            xml.push('\n');
        }
    }

    // Ensure we have highway=path for pedestrian routing
    if !feature.properties.as_object().map_or(false, |o| o.contains_key("highway")) {
        xml.push_str(r#"    <tag k="highway" v="path"/>"#);
        xml.push('\n');
    }
    if !feature.properties.as_object().map_or(false, |o| o.contains_key("foot")) {
        xml.push_str(r#"    <tag k="foot" v="designated"/>"#);
        xml.push('\n');
    }

    xml.push_str(&format!("  </way>",));
    xml.push('\n');

    xml
}

/// Converts an entire GeoJSON FeatureCollection to OSM XML format.
pub fn collection_to_osm_xml(collection: &GeoJsonFeatureCollection) -> String {
    let mut xml = String::from(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="runit-maps">
"#,
    );

    let mut way_offset: u64 = 1_000_000_000; // Start custom IDs high to avoid conflicts
    let mut node_offset: u64 = 2_000_000_000;

    for feature in &collection.features {
        if feature.geometry.geometry_type == "LineString" {
            xml.push_str(&feature_to_osm_xml(feature, way_offset, node_offset));
            way_offset += 1;
            node_offset += (feature.geometry.coordinates.len() as u64) + 1;
        }
    }

    xml.push_str("</osm>\n");
    xml
}

/// Loads all campus path names from all GeoJSON files in the given directory.
/// Returns a set of path names for use in detecting custom paths in route responses.
pub fn load_campus_path_names(custom_paths_dir: &Path) -> HashSet<String> {
    let mut names = HashSet::new();
    let dir = match std::fs::read_dir(custom_paths_dir) {
        Ok(d) => d,
        Err(_) => return names,
    };
    for entry in dir.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("geojson") {
            continue;
        }
        if let Ok(collection) = parse_geojson(&path) {
            for feature in &collection.features {
                if let Some(name) = feature.properties.get("name").and_then(|v| v.as_str()) {
                    names.insert(name.to_string());
                }
            }
        }
    }
    names
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_geojson() {
        let geojson = r#"{
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {
                    "name": "Test Path",
                    "campus_id": "mit",
                    "surface": "paved"
                },
                "geometry": {
                    "type": "LineString",
                    "coordinates": [[-71.092, 42.358], [-71.090, 42.360], [-71.088, 42.362]]
                }
            }]
        }"#;

        let path = std::env::temp_dir().join("test_paths.geojson");
        std::fs::write(&path, geojson).unwrap();

        let result = parse_geojson(&path);
        assert!(result.is_ok());
        let collection = result.unwrap();
        assert_eq!(collection.features.len(), 1);

        let xml = collection_to_osm_xml(&collection);
        assert!(xml.contains("node id=\"2000000000\""));
        assert!(xml.contains("<tag k=\"campus_id\" v=\"mit\"/>"));
        assert!(xml.contains("<tag k=\"highway\" v=\"path\"/>"));
        assert!(xml.contains("<tag k=\"foot\" v=\"designated\"/>"));

        std::fs::remove_file(&path).unwrap();
    }
}
