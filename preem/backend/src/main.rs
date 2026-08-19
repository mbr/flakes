//! Runs the web application.

mod api;
mod config;
mod db;
mod error;
mod middleware;
mod web;

/// Runs the web application.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config: config::Config = twelve::config::from_args()?;

    twelve::logging::init(config.core.log_filter)?;

    let database = db::connect(config.database_url).await?;
    web::run(config.core.listen_address, config.frontend, database).await
}
