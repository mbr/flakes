//! Serves the JSON API and compiled frontend.

use std::{fs, future::Future, io, os::unix::fs::PermissionsExt, path::PathBuf};

use axum::{Json, Router, extract::State, routing::get};
use sqlx::PgPool;
use tokio::{
    net::{TcpListener, UnixListener},
    signal::{
        ctrl_c,
        unix::{SignalKind, signal},
    },
};
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::info;

use crate::{
    api::StatusResponse,
    config::ListenAddress,
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
    listen_address: ListenAddress,
    frontend: PathBuf,
    database: PgPool,
) -> anyhow::Result<()> {
    let application = router(frontend.clone(), database);
    let shutdown = shutdown_signal()?;

    match listen_address {
        ListenAddress::Tcp(address) => {
            let listener = TcpListener::bind(address).await?;
            let address = listener.local_addr()?;

            info!(%address, frontend = %frontend.display(), "web server listening");
            axum::serve(listener, application)
                .with_graceful_shutdown(shutdown)
                .await?;
        }
        ListenAddress::Unix(path) => {
            let listener = UnixListener::bind(&path)?;
            fs::set_permissions(&path, fs::Permissions::from_mode(0o660))?;

            info!(path = %path.display(), frontend = %frontend.display(), "web server listening");
            axum::serve(listener, application)
                .with_graceful_shutdown(shutdown)
                .await?;
        }
    }

    info!("web server stopped");
    Ok(())
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
