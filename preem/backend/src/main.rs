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

    twelve::logging::init(config.core.log_filter)?;

    let database =
        twelve::postgres::connect_and_migrate(config.database_url, &sqlx::migrate!()).await?;
    web::run(config.core.listen_address, config.frontend, database).await
}
