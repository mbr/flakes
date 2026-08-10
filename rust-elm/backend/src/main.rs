//! Runs the web application.

use std::{net::SocketAddr, path::PathBuf};

use clap::Parser;
use tracing_subscriber::{EnvFilter, fmt, prelude::*};

mod api;
mod web;

/// Configures the web application.
#[derive(Debug, Parser)]
#[command(version, about)]
struct Args {
    /// Address on which the HTTP server listens.
    #[arg(long, env = "APP_BIND_ADDRESS", default_value = "127.0.0.1:3000")]
    bind_address: SocketAddr,

    /// Directory containing the built frontend.
    #[arg(long, env = "APP_FRONTEND")]
    frontend: PathBuf,
}

/// Runs the web application.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(fmt::layer())
        .with(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("myapp=info,tower_http=info")),
        )
        .init();

    let args = Args::parse();
    web::run(args.bind_address, args.frontend).await
}
