use crate::common::error::ServiceError;
use crate::common::polyline;
use crate::proto::runit_maps::v1::{
    LatLng, ManeuverType, RouteRequest, RouteResponse, RouteStep, RouteSummary,
};
use std::collections::HashSet;

/// Maps Valhalla maneuver type integers to our proto enum.
fn maneuver_type_from_valhalla(valhalla_type: i32) -> ManeuverType {
    match valhalla_type {
        0 => ManeuverType::Turn,            // kTurn
        1 => ManeuverType::Continue,         // kContinue
        2 => ManeuverType::Depart,           // kStart
        3 => ManeuverType::Arrive,           // kEnd
        4 => ManeuverType::RoundaboutEnter,  // kRoundaboutEnter
        5 => ManeuverType::RoundaboutExit,   // kRoundaboutExit
        6 => ManeuverType::CrossStreet,      // kStart = cross street
        _ => ManeuverType::Turn,
    }
}

/// Parses a Valhalla /route JSON response into our proto RouteResponse.
pub fn parse_valhalla_response(
    raw: &serde_json::Value,
    _req: &RouteRequest,
    campus_path_names: &HashSet<String>,
) -> Result<RouteResponse, ServiceError> {
    let trip = raw
        .get("trip")
        .ok_or_else(|| ServiceError::Valhalla("missing 'trip' field".into()))?;

    let legs = trip
        .get("legs")
        .and_then(|v| v.as_array())
        .ok_or_else(|| ServiceError::Valhalla("missing or invalid 'legs' array".into()))?;

    let leg = legs.first().ok_or_else(|| {
        ServiceError::Valhalla("no route legs returned".into())
    })?;

    // --- Summary ---
    let summary = leg
        .get("summary")
        .ok_or_else(|| ServiceError::Valhalla("missing leg 'summary'".into()))?;

    let distance_meters = summary
        .get("length")
        .and_then(|v| v.as_f64())
        .unwrap_or(0.0)
        * 1000.0; // Valhalla returns km

    let duration_seconds = summary
        .get("time")
        .and_then(|v| v.as_f64())
        .unwrap_or(0.0);

    let duration_formatted = format_duration(duration_seconds as u64);

    // --- Shape (full polyline) ---
    let shape = leg
        .get("shape")
        .and_then(|v| v.as_str())
        .ok_or_else(|| ServiceError::Valhalla("missing leg 'shape'".into()))?;

    let decoded_shape = polyline::decode_points(shape);

    // --- Steps (maneuvers) ---
    let maneuvers = leg
        .get("maneuvers")
        .and_then(|v| v.as_array())
        .map(|arr| arr.to_vec())
        .unwrap_or_default();

    let steps: Vec<RouteStep> = maneuvers
        .iter()
        .enumerate()
        .map(|(i, maneuver)| {
            let instruction = maneuver
                .get("instruction")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();

            let street_name = maneuver
                .get("street_names")
                .and_then(|v| v.as_array())
                .and_then(|arr| arr.first())
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();

            let start_lat = maneuver
                .get("begin_shape_index")
                .and_then(|v| v.as_u64())
                .and_then(|idx| decoded_shape.get(idx as usize))
                .map(|p| p.lat)
                .unwrap_or(0.0);
            let start_lng = maneuver
                .get("begin_shape_index")
                .and_then(|v| v.as_u64())
                .and_then(|idx| decoded_shape.get(idx as usize))
                .map(|p| p.lng)
                .unwrap_or(0.0);

            let step_length = maneuver
                .get("length")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0)
                * 1000.0;
            let step_time = maneuver
                .get("time")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0);

            let maneuver_type_val = maneuver
                .get("type")
                .and_then(|v| v.as_i64())
                .unwrap_or(1) as i32;
            let maneuver_type = maneuver_type_from_valhalla(maneuver_type_val);

            let direction = maneuver
                .get("direction")
                .and_then(|v| v.as_str())
                .unwrap_or("straight")
                .to_string();

            let is_custom_path = campus_path_names.contains(&street_name);

            RouteStep {
                step_number: i as i32 + 1,
                instruction,
                street_name,
                start_location: Some(LatLng {
                    lat: start_lat,
                    lng: start_lng,
                }),
                encoded_polyline: String::new(), // per-step polyline not always available
                distance_meters: step_length as f32,
                duration_seconds: step_time as f32,
                maneuver_type: maneuver_type.into(),
                direction,
                is_custom_path,
            }
        })
        .collect();

    Ok(RouteResponse {
        encoded_polyline: shape.to_string(),
        summary: Some(RouteSummary {
            distance_meters: distance_meters as f32,
            duration_seconds: duration_seconds as f32,
            distance_km: (distance_meters / 1000.0) as f32,
            duration_formatted,
        }),
        steps,
        alternatives: vec![],
    })
}

fn format_duration(seconds: u64) -> String {
    let minutes = seconds / 60;
    let hours = minutes / 60;
    if hours > 0 {
        format!("{} hr {} min", hours, minutes % 60)
    } else {
        format!("{} min", minutes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_valhalla_response() -> serde_json::Value {
        serde_json::json!({
            "trip": {
                "language": "en-US",
                "legs": [{
                    "summary": {
                        "length": 1.5,
                        "time": 720.0,
                        "min_lat": 42.358,
                        "min_lon": -71.092,
                        "max_lat": 42.365,
                        "max_lon": -71.084
                    },
                    "shape": "y_|bF|bw}K_Ai@}Bk@eDJgD",
                    "maneuvers": [{
                        "type": 1,
                        "instruction": "Walk east on Main Street",
                        "street_names": ["Main Street"],
                        "length": 0.5,
                        "time": 240.0,
                        "begin_shape_index": 0,
                        "end_shape_index": 5,
                        "direction": "east"
                    }, {
                        "type": 2,
                        "instruction": "You have arrived at your destination",
                        "street_names": [],
                        "length": 1.0,
                        "time": 480.0,
                        "begin_shape_index": 5,
                        "end_shape_index": 10,
                        "direction": "straight"
                    }]
                }],
                "status": 0,
                "units": "kilometers"
            }
        })
    }

    #[test]
    fn test_parse_valhalla_response() {
        let raw = sample_valhalla_response();
        let req = RouteRequest::default();
        let campus_names = HashSet::new();
        let result = parse_valhalla_response(&raw, &req, &campus_names);

        assert!(result.is_ok());
        let response = result.unwrap();

        // Check summary
        let summary = response.summary.unwrap();
        assert!((summary.distance_meters - 1500.0).abs() < 0.1);
        assert!((summary.duration_seconds - 720.0).abs() < 0.1);
        assert_eq!(summary.duration_formatted, "12 min");

        // Check steps
        assert_eq!(response.steps.len(), 2);
        assert_eq!(response.steps[0].instruction, "Walk east on Main Street");
        assert_eq!(response.steps[0].street_name, "Main Street");

        // Check polyline
        assert!(!response.encoded_polyline.is_empty());
    }
}
