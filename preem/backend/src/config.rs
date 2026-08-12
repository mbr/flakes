//! Loads application configuration from TOML.

use std::{
    fs,
    net::SocketAddr,
    path::{Path, PathBuf},
};

use serde::Deserialize;
use thiserror::Error;

use crate::db::DatabaseUrl;

/// Configures the web application.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    /// Address on which the HTTP server listens.
    pub bind_address: SocketAddr,

    /// PostgreSQL connection URL.
    pub database_url: DatabaseUrl,

    /// Directory containing the built frontend.
    pub frontend: PathBuf,

    /// Tracing filter applied by the application.
    pub log_filter: String,
}

/// Describes failures while loading application configuration.
#[derive(Debug, Error)]
pub enum LoadError {
    /// The configuration file could not be read.
    #[error("failed to read configuration from {path}")]
    Read {
        /// Path to the configuration file.
        path: PathBuf,

        /// Underlying filesystem error.
        #[source]
        source: std::io::Error,
    },

    /// The configuration file contains invalid TOML or values.
    #[error("failed to parse configuration from {path}")]
    Parse {
        /// Path to the configuration file.
        path: PathBuf,

        /// Underlying TOML error.
        #[source]
        source: toml::de::Error,
    },
}

/// Loads application configuration from a TOML file.
pub fn load(path: &Path) -> Result<Config, LoadError> {
    let serialized = fs::read_to_string(path).map_err(|source| LoadError::Read {
        path: path.to_owned(),
        source,
    })?;

    toml::from_str(&serialized).map_err(|source| LoadError::Parse {
        path: path.to_owned(),
        source,
    })
}
