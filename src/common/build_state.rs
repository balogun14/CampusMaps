use crate::proto::runit_maps::v1::TileBuildStatus;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

/// Tracks the state of tile build jobs per region.
pub type BuildState = Arc<Mutex<HashMap<String, BuildJob>>>;

/// Creates a new empty BuildState.
pub fn new_build_state() -> BuildState {
    Arc::new(Mutex::new(HashMap::new()))
}

/// Status of a single tile build job for a region.
pub struct BuildJob {
    pub status: TileBuildStatus,
    pub error_message: Option<String>,
    pub last_build_time: Option<SystemTime>,
    pub last_build_duration_secs: Option<f32>,
}
