use crate::common::error::ServiceError;
use crate::proto::runit_maps::v1::RouteRequest;

pub fn validate_route_request(req: &RouteRequest) -> Result<(), ServiceError> {
    let origin = req
        .origin
        .as_ref()
        .ok_or_else(|| ServiceError::Validation("origin is required".into()))?;

    let destination = req
        .destination
        .as_ref()
        .ok_or_else(|| ServiceError::Validation("destination is required".into()))?;

    if !is_valid_latlng(origin.lat, origin.lng) {
        return Err(ServiceError::Validation(
            "origin has invalid coordinates".into(),
        ));
    }

    if !is_valid_latlng(destination.lat, destination.lng) {
        return Err(ServiceError::Validation(
            "destination has invalid coordinates".into(),
        ));
    }

    Ok(())
}

fn is_valid_latlng(lat: f64, lng: f64) -> bool {
    lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proto::runit_maps::v1::{LatLng, RouteRequest};

    #[test]
    fn test_valid_request() {
        let req = RouteRequest {
            origin: Some(LatLng { lat: 42.358, lng: -71.092 }),
            destination: Some(LatLng { lat: 42.365, lng: -71.084 }),
            ..Default::default()
        };
        assert!(validate_route_request(&req).is_ok());
    }

    #[test]
    fn test_missing_origin() {
        let req = RouteRequest {
            origin: None,
            destination: Some(LatLng { lat: 42.365, lng: -71.084 }),
            ..Default::default()
        };
        assert!(validate_route_request(&req).is_err());
    }

    #[test]
    fn test_invalid_latlng() {
        let req = RouteRequest {
            origin: Some(LatLng { lat: 100.0, lng: -71.092 }),
            destination: Some(LatLng { lat: 42.365, lng: -71.084 }),
            ..Default::default()
        };
        assert!(validate_route_request(&req).is_err());
    }
}
