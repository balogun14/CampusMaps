use crate::proto::runit_maps::v1::LatLng;

/// Encodes a slice of (lat, lng) pairs into a Google-encoded polyline string.
pub fn encode_points(points: &[LatLng]) -> String {
    let coords: Vec<(f64, f64)> = points.iter().map(|p| (p.lat, p.lng)).collect();
    polyline::encode_coordinates(&coords, 5).unwrap_or_default()
}

/// Decodes a Google-encoded polyline string into a vector of LatLng.
pub fn decode_points(encoded: &str) -> Vec<LatLng> {
    polyline::decode_coordinates(encoded, 5)
        .unwrap_or_default()
        .into_iter()
        .map(|(lat, lng)| LatLng { lat, lng })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_roundtrip() {
        let original = vec![
            LatLng { lat: 42.358, lng: -71.092 },
            LatLng { lat: 42.360, lng: -71.090 },
            LatLng { lat: 42.365, lng: -71.084 },
        ];
        let encoded = encode_points(&original);
        let decoded = decode_points(&encoded);

        assert_eq!(original.len(), decoded.len());
        for (a, b) in original.iter().zip(decoded.iter()) {
            assert!((a.lat - b.lat).abs() < 0.0001);
            assert!((a.lng - b.lng).abs() < 0.0001);
        }
    }
}
