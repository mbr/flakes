//! Runs the web application.

use std::{net::SocketAddr, path::PathBuf};

use clap::Parser;
use tracing_subscriber::EnvFilter;

mod api;
mod db;
mod error;
mod web;

/// Configures the web application.
#[derive(Debug, Parser)]
#[command(version, about)]
struct Args {
    /// Address on which the HTTP server listens.
    #[arg(long, env = "APP_BIND_ADDRESS", default_value = "127.0.0.1:3000")]
    bind_address: SocketAddr,

    /// PostgreSQL connection URL.
    #[arg(long, env = "DATABASE_URL")]
    database_url: db::DatabaseUrl,

    /// Directory containing the built frontend.
    #[arg(long, env = "APP_FRONTEND")]
    frontend: PathBuf,
}

/// Runs the web application.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("myapp=info,tower_http=info")),
        )
        .init();

    let args = Args::parse();
    let database = db::connect(args.database_url).await?;
    web::run(args.bind_address, args.frontend, database).await
}
