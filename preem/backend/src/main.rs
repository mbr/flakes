//! Runs the web application.

use tracing_subscriber::EnvFilter;

mod api;
mod config;
mod db;
mod error;
mod listener;
mod web;

/// Runs the web application.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = config::Config::from_args()?;

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_new(&config.log_filter)?)
        .init();

    let database = db::connect(config.database_url).await?;
    web::run(config.listen_address, config.frontend, database).await
}
