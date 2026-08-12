//! Serves the JSON API and compiled frontend.

use std::{net::SocketAddr, path::PathBuf};

use axum::{Json, Router, routing::get};
use tokio::net::TcpListener;
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::info;

use crate::{
    api::StatusResponse,
    error::{AppError, AppResult},
};

/// Runs the HTTP server.
pub async fn run(bind_address: SocketAddr, frontend: PathBuf) -> anyhow::Result<()> {
    let listener = TcpListener::bind(bind_address).await?;
    let address = listener.local_addr()?;

    info!(%address, frontend = %frontend.display(), "web server listening");

    axum::serve(listener, router(frontend)).await?;
    Ok(())
}

/// Builds the application router.
fn router(frontend: PathBuf) -> Router {
    let api = Router::new()
        .route("/status", get(status))
        .fallback(api_not_found)
        .method_not_allowed_fallback(method_not_allowed);

    Router::new()
        .nest("/api", api)
        .fallback_service(ServeDir::new(frontend))
        .layer(TraceLayer::new_for_http())
}

/// Returns the current service status.
async fn status() -> AppResult<Json<StatusResponse>> {
    Ok(Json(StatusResponse { status: "ok" }))
}

/// Returns the structured API route error.
async fn api_not_found() -> AppResult<()> {
    Err(AppError::RouteNotFound)
}

/// Returns the structured API method error.
async fn method_not_allowed() -> AppResult<()> {
    Err(AppError::MethodNotAllowed)
}
