//! Runs the web application.

mod api;
mod config;
mod error;
mod web;

use axum::Extension;
use twelve::urls::UrlSource;

/// Runs the web application.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config: config::Config = twelve::config::from_args()?;
    // For external links, use `config.core.url_source()` and enable Nix URL support.
    let url_source = UrlSource::internal("/");

    twelve::logging::init(config.core.log_filter)?;

    let database =
        twelve::postgres::connect_and_migrate(config.database_url, &sqlx::migrate!()).await?;
    let application = web::router(config.frontend, database).layer(Extension(url_source));

    twelve::serve(&config.core.listen_address, application).await?;
    Ok(())
}
