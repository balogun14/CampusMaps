use crate::common::error::ServiceError;
use std::path::Path;
use tracing::info;

/// Downloads an OSM PBF file from Geofabrik if not already cached.
pub async fn download_osm_pbf(url: &str, dest_path: &Path) -> Result<(), ServiceError> {
    if dest_path.exists() {
        info!(
            "OSM PBF already cached at {}",
            dest_path.display()
        );
        return Ok(());
    }

    info!(url = %url, dest = %dest_path.display(), "Downloading OSM PBF");

    let client = reqwest::Client::new();
    let response = client.get(url).send().await?;

    if !response.status().is_success() {
        return Err(ServiceError::Valhalla(format!(
            "Failed to download OSM PBF: HTTP {}",
            response.status()
        )));
    }

    let bytes = response.bytes().await?;

    // Ensure parent directory exists
    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    tokio::fs::write(dest_path, &bytes).await?;

    info!(
        "Downloaded {} bytes to {}",
        bytes.len(),
        dest_path.display()
    );

    Ok(())
}
