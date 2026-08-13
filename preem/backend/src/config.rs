//! Defines application configuration values.

use std::path::PathBuf;

use serde::Deserialize;
use twelve::{config::Core, postgres::DatabaseUrl};

/// Configures the web application.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    /// Provides shared listener and tracing configuration.
    #[serde(flatten)]
    pub core: Core,

    /// Selects the PostgreSQL database.
    pub database_url: DatabaseUrl,

    /// Selects the directory containing the built frontend.
    pub frontend: PathBuf,
}
