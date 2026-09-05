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

/// Converts an entire GeoJSON FeatureCollection to OSM XML format.
/// Nodes are listed first, then ways — required by osmium merge.
pub fn collection_to_osm_xml(collection: &GeoJsonFeatureCollection) -> String {
    let mut xml = String::from(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="runit-maps">
"#,
    );

    // First pass: collect all nodes and prepare way data
    let mut node_id: u64 = 2_000_000_000;
    let mut way_id: u64 = 1_000_000_000;
    let mut all_nodes = Vec::new();
    #[derive(Clone)]
    struct WayData {
        id: u64,
        nd_refs: Vec<u64>,
        properties: serde_json::Value,
    }
    let mut ways = Vec::new();

    for feature in &collection.features {
        if feature.geometry.geometry_type != "LineString" {
            continue;
        }
        let mut nd_refs = Vec::new();
        for coord in &feature.geometry.coordinates {
            if coord.len() >= 2 {
                all_nodes.push((node_id, coord[1], coord[0]));
                nd_refs.push(node_id);
                node_id += 1;
            }
        }
        ways.push(WayData {
            id: way_id,
            nd_refs,
            properties: feature.properties.clone(),
        });
        way_id += 1;
    }

    // Output all nodes
    for (id, lat, lon) in &all_nodes {
        xml.push_str(&format!(
            r#"  <node id="{}" lat="{}" lon="{}" version="1" visible="true"/>"#,
            id, lat, lon
        ));
        xml.push('\n');
    }

    // Output all ways
    for way in &ways {
        xml.push_str(&format!(
            r#"  <way id="{}" version="1" visible="true">"#,
            way.id
        ));
        xml.push('\n');
        for nd in &way.nd_refs {
            xml.push_str(&format!("    <nd ref=\"{}\"/>\n", nd));
        }
        if let Some(obj) = way.properties.as_object() {
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
        if !way.properties.as_object().map_or(false, |o| o.contains_key("highway")) {
            xml.push_str(r#"    <tag k="highway" v="path"/>"#);
            xml.push('\n');
        }
        if !way.properties.as_object().map_or(false, |o| o.contains_key("foot")) {
            xml.push_str(r#"    <tag k="foot" v="designated"/>"#);
            xml.push('\n');
        }
        xml.push_str("  </way>\n");
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
