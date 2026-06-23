use crate::common::error::ServiceError;
use reqwest::Client as HttpClient;
use std::time::Duration;
use tracing::info;

pub struct ValhallaClient {
    client: HttpClient,
    base_url: String,
    timeout: Duration,
}

impl ValhallaClient {
    pub fn new(base_url: String) -> Self {
        let client = HttpClient::builder()
            .pool_max_idle_per_host(32)
            .timeout(Duration::from_secs(10))
            .build()
            .expect("Failed to create HTTP client");

        Self {
            client,
            base_url,
            timeout: Duration::from_secs(10),
        }
    }

    pub async fn route(&self, request: &serde_json::Value) -> Result<serde_json::Value, ServiceError> {
        let url = format!("{}/route", self.base_url);
        info!(url = %url, "Calling Valhalla route API");

        let response = self
            .client
            .post(&url)
            .json(request)
            .timeout(self.timeout)
            .send()
            .await?;

        let status = response.status();
        if !status.is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(ServiceError::Valhalla(format!(
                "Valhalla returned {}: {}",
                status,
                body
            )));
        }

        Ok(response.json::<serde_json::Value>().await?)
    }

    pub async fn health_check(&self) -> Result<(), ServiceError> {
        let url = format!("{}/health", self.base_url);
        let response = self
            .client
            .get(&url)
            .timeout(Duration::from_secs(3))
            .send()
            .await?;

        if response.status().is_success() {
            Ok(())
        } else {
            Err(ServiceError::Valhalla(format!(
                "Health check failed: {}",
                response.status()
            )))
        }
    }
}
