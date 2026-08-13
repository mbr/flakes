//! Runs the web application.

mod api;
mod config;
mod db;
mod error;
mod web;

/// Runs the web application.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config: config::Config = twelve::config::from_args()?;

    tracing_subscriber::fmt()
        .with_env_filter(config.core.log_filter)
        .init();

    let database = db::connect(config.database_url).await?;
    web::run(config.core.listen_address, config.frontend, database).await
}
