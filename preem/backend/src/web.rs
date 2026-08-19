//! Serves the JSON API and compiled frontend.

use std::path::PathBuf;

use axum::{Json, Router, extract::State, middleware, routing::get};
use sqlx::PgPool;
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::info;
use twelve::{config::ListenAddress, listener::Listener};

use crate::{
    api::StatusResponse,
    db,
    error::{AppError, AppResult},
    middleware::{
        frontend_cache,
        frontend_version::{FrontendVersion, attach},
    },
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
    let frontend_version = FrontendVersion::new(frontend.join("static/frontend-version"));
    let application = router(frontend.clone(), database, frontend_version);
    let shutdown = twelve::shutdown_signal();

    let listener = Listener::bind(&listen_address).await?;

    info!(address = %listener.local_address(), frontend = %frontend.display(), "web server listening");
    axum::serve(listener, application)
        .with_graceful_shutdown(shutdown)
        .await?;

    info!("web server stopped");
    Ok(())
}

/// Builds the application router.
fn router(frontend: PathBuf, database: PgPool, frontend_version: FrontendVersion) -> Router {
    let api = Router::new()
        .route("/status", get(status))
        .fallback(api_not_found)
        .method_not_allowed_fallback(method_not_allowed)
        .layer(middleware::from_fn_with_state(frontend_version, attach));

    let frontend = Router::new()
        .fallback_service(ServeDir::new(frontend).append_index_html_on_directories(true))
        .layer(middleware::from_fn(frontend_cache::set));

    Router::new()
        .nest("/api", api)
        .merge(frontend)
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

#[cfg(test)]
mod tests {
    use std::fs;

    use axum::{
        body::Body,
        http::{Request, header::CACHE_CONTROL},
    };
    use sqlx::postgres::PgPoolOptions;
    use tempfile::tempdir;
    use tower::ServiceExt;

    use super::router;
    use crate::middleware::frontend_version::FrontendVersion;

    /// First frontend version used by the tests.
    const VERSION_A: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    /// Applies API version and frontend cache response headers.
    #[tokio::test]
    async fn applies_frontend_response_headers() {
        let frontend = tempdir().expect("temporary frontend should be created");
        let static_assets = frontend.path().join("static");
        let versioned_assets = static_assets.join(VERSION_A);
        fs::create_dir_all(&versioned_assets).expect("asset directory should be created");
        fs::write(static_assets.join("frontend-version"), VERSION_A)
            .expect("manifest should be written");
        fs::write(frontend.path().join("index.html"), "<!doctype html>")
            .expect("index should be written");
        fs::write(versioned_assets.join("app.js"), "").expect("asset should be written");
        let frontend_version = FrontendVersion::new(static_assets.join("frontend-version"));
        let database = PgPoolOptions::new()
            .connect_lazy("postgres://dev:dev@localhost/dev")
            .expect("database URL should be valid");
        let application = router(frontend.path().to_owned(), database, frontend_version);

        let api_response = application
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/missing")
                    .body(Body::empty())
                    .expect("API request should be built"),
            )
            .await
            .expect("API request should complete");
        assert_eq!(api_response.headers()["frontend-version"], VERSION_A);
        assert!(api_response.headers().get(CACHE_CONTROL).is_none());

        let index_response = application
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/")
                    .body(Body::empty())
                    .expect("index request should be built"),
            )
            .await
            .expect("index request should complete");
        assert_eq!(index_response.headers()[CACHE_CONTROL], "no-cache");

        let asset_response = application
            .oneshot(
                Request::builder()
                    .uri(format!("/static/{VERSION_A}/app.js"))
                    .body(Body::empty())
                    .expect("asset request should be built"),
            )
            .await
            .expect("asset request should complete");
        assert_eq!(
            asset_response.headers()[CACHE_CONTROL],
            "public, max-age=31536000, immutable"
        );
    }
}
