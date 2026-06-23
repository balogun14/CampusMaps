pub mod api;
pub mod common;
pub mod config;
pub mod ingestion;
pub mod routing;

pub mod proto {
    pub mod runit_maps {
        pub mod v1 {
            include!(concat!(env!("OUT_DIR"), "/runit_maps.v1.rs"));
        }
    }
}
