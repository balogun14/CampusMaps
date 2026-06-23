use std::fmt;

#[derive(Debug)]
pub enum ServiceError {
    Valhalla(String),
    Http(reqwest::Error),
    Validation(String),
    Timeout,
    TileBuild(String),
    Config(String),
    Io(std::io::Error),
    Serde(serde_json::Error),
}

impl fmt::Display for ServiceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Valhalla(msg) => write!(f, "Valhalla error: {}", msg),
            Self::Http(err) => write!(f, "HTTP request failed: {}", err),
            Self::Validation(msg) => write!(f, "Validation error: {}", msg),
            Self::Timeout => write!(f, "Valhalla request timed out"),
            Self::TileBuild(msg) => write!(f, "Tile build failed: {}", msg),
            Self::Config(msg) => write!(f, "Configuration error: {}", msg),
            Self::Io(err) => write!(f, "I/O error: {}", err),
            Self::Serde(err) => write!(f, "Serialization error: {}", err),
        }
    }
}

impl std::error::Error for ServiceError {}

impl From<reqwest::Error> for ServiceError {
    fn from(err: reqwest::Error) -> Self {
        if err.is_timeout() {
            Self::Timeout
        } else {
            Self::Http(err)
        }
    }
}

impl From<std::io::Error> for ServiceError {
    fn from(err: std::io::Error) -> Self {
        Self::Io(err)
    }
}

impl From<serde_json::Error> for ServiceError {
    fn from(err: serde_json::Error) -> Self {
        Self::Serde(err)
    }
}

impl From<ServiceError> for tonic::Status {
    fn from(err: ServiceError) -> Self {
        match &err {
            ServiceError::Validation(msg) => tonic::Status::invalid_argument(msg),
            ServiceError::Timeout => tonic::Status::deadline_exceeded(err.to_string()),
            _ => tonic::Status::internal(err.to_string()),
        }
    }
}
