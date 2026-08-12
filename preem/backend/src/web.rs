//! Serves the JSON API and compiled frontend.

use std::{net::SocketAddr, path::PathBuf};

use axum::{Json, Router, extract::State, routing::get};
use sqlx::PgPool;
use tokio::net::TcpListener;
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::info;

use crate::{
    api::StatusResponse,
    db,
    error::{AppError, AppResult},
};

/// Holds resources shared by HTTP handlers.
#[derive(Clone)]
struct AppState {
    /// PostgreSQL connection pool.
    database: PgPool,
}

/// Runs the HTTP server.
pub async fn run(
    bind_address: SocketAddr,
    frontend: PathBuf,
    database: PgPool,
) -> anyhow::Result<()> {
    let listener = TcpListener::bind(bind_address).await?;
    let address = listener.local_addr()?;

    info!(%address, frontend = %frontend.display(), "web server listening");

    axum::serve(listener, router(frontend, database)).await?;
    Ok(())
}

/// Builds the application router.
fn router(frontend: PathBuf, database: PgPool) -> Router {
    let api = Router::new()
        .route("/status", get(status))
        .fallback(api_not_found)
        .method_not_allowed_fallback(method_not_allowed);

    Router::new()
        .nest("/api", api)
        .fallback_service(ServeDir::new(frontend))
        .layer(TraceLayer::new_for_http())
        .with_state(AppState { database })
}

/// Returns the current service status.
async fn status(State(state): State<AppState>) -> AppResult<Json<StatusResponse>> {
    let mut connection = state.database.acquire().await?;
    let database_status = db::status(&mut connection).await?;

    Ok(Json(StatusResponse {
        status: "ok",
        database_ready: database_status.ready,
    }))
}

/// Returns the structured API route error.
async fn api_not_found() -> AppResult<()> {
    Err(AppError::RouteNotFound)
}

/// Returns the structured API method error.
async fn method_not_allowed() -> AppResult<()> {
    Err(AppError::MethodNotAllowed)
}
