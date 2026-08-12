//! Serves the JSON API and compiled frontend.

use std::{future::Future, io, path::PathBuf};

use axum::{Json, Router, extract::State, routing::get};
use sd_notify::NotifyState;
use sqlx::PgPool;
use tokio::signal::{
    ctrl_c,
    unix::{SignalKind, signal},
};
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::info;

use crate::{
    api::StatusResponse,
    config::ListenAddress,
    db,
    error::{AppError, AppResult},
    listener::{self, Listener},
};

/// Holds resources shared by HTTP handlers.
#[derive(Clone)]
struct AppState {
    /// PostgreSQL connection pool.
    database: PgPool,
}

/// Runs the HTTP server.
pub async fn run(
    listen_address: ListenAddress,
    frontend: PathBuf,
    database: PgPool,
) -> anyhow::Result<()> {
    let application = router(frontend.clone(), database);
    let shutdown = shutdown_signal()?;

    match listener::open(&listen_address).await? {
        Listener::Tcp(listener) => {
            let address = listener.local_addr()?;

            notify_ready()?;
            info!(%address, frontend = %frontend.display(), "web server listening");
            axum::serve(listener, application)
                .with_graceful_shutdown(shutdown)
                .await?;
        }
        Listener::Unix(listener) => {
            let path = listener.local_addr()?;

            notify_ready()?;
            info!(path = ?path.as_pathname(), frontend = %frontend.display(), "web server listening");
            axum::serve(listener, application)
                .with_graceful_shutdown(shutdown)
                .await?;
        }
    }

    info!("web server stopped");
    Ok(())
}

/// Reports that application startup is complete when supervised by a service manager.
fn notify_ready() -> io::Result<()> {
    sd_notify::notify(&[
        NotifyState::Ready,
        NotifyState::Status("Serving HTTP requests"),
    ])
}

/// Waits for an operating-system shutdown signal.
fn shutdown_signal() -> io::Result<impl Future<Output = ()>> {
    let mut terminate = signal(SignalKind::terminate())?;

    Ok(async move {
        tokio::select! {
            result = ctrl_c() => {
                if let Err(error) = result {
                    tracing::warn!(%error, "failed to receive interrupt signal");
                }
            }
            _ = terminate.recv() => {}
        }

        info!("shutdown signal received");
    })
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
