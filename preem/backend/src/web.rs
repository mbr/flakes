//! Serves the JSON API and compiled frontend.

use std::path::PathBuf;

use axum::{
    Json, Router,
    extract::{Request, State},
    http::{HeaderValue, StatusCode, header::CACHE_CONTROL},
    middleware::{self, Next},
    response::Response,
    routing::get,
};
use sqlx::PgPool;
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::info;
use twelve::{config::ListenAddress, listener::Listener};

use crate::{
    api::StatusResponse,
    db,
    error::{AppError, AppResult},
    middleware::frontend_version::{FrontendVersion, attach},
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
    let frontend_version = FrontendVersion::new(frontend.join("frontend-version"));
    let application = router(frontend.clone(), database, frontend_version);
    let shutdown = twelve::shutdown_signal();

    let listener = Listener::bind(&listen_address).await?;

    twelve::systemd::ready_with_status("Serving HTTP requests")?;
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

    Router::new()
        .nest("/api", api)
        .fallback_service(ServeDir::new(frontend))
        .layer(middleware::from_fn(set_frontend_cache_policy))
        .layer(TraceLayer::new_for_http())
        .with_state(AppState { database })
}

/// Sets cache headers for responses served by the frontend fallback.
async fn set_frontend_cache_policy(request: Request, next: Next) -> Response {
    let path = request.uri().path().to_owned();
    let mut response = next.run(request).await;

    if path != "/api" && !path.starts_with("/api/") {
        let cache_control = if is_fingerprinted_asset(&path)
            && (response.status().is_success() || response.status() == StatusCode::NOT_MODIFIED)
        {
            HeaderValue::from_static("public, max-age=31536000, immutable")
        } else {
            HeaderValue::from_static("no-cache")
        };
        response.headers_mut().insert(CACHE_CONTROL, cache_control);
    }

    response
}

/// Reports whether a request path names a content-addressed frontend asset.
fn is_fingerprinted_asset(path: &str) -> bool {
    let Some(filename) = path.rsplit('/').next() else {
        return false;
    };
    let Some(name) = filename.strip_prefix("app-") else {
        return false;
    };
    let digest = name
        .strip_suffix(".js")
        .or_else(|| name.strip_suffix(".css"));

    digest.is_some_and(|digest| {
        digest.len() == 64
            && digest
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    })
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

    use super::{is_fingerprinted_asset, router};
    use crate::middleware::frontend_version::FrontendVersion;

    /// First frontend version used by the tests.
    const VERSION_A: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    /// Recognizes only generated content-addressed asset names.
    #[test]
    fn recognizes_fingerprinted_assets() {
        assert!(is_fingerprinted_asset(&format!("/app-{VERSION_A}.js")));
        assert!(is_fingerprinted_asset(&format!("/app-{VERSION_A}.css")));
        assert!(!is_fingerprinted_asset("/app.js"));
        assert!(!is_fingerprinted_asset("/app-not-a-digest.js"));
        assert!(!is_fingerprinted_asset(&format!("/other-{VERSION_A}.js")));
    }

    /// Applies API version and frontend cache response headers.
    #[tokio::test]
    async fn applies_frontend_response_headers() {
        let frontend = tempdir().expect("temporary frontend should be created");
        fs::write(frontend.path().join("frontend-version"), VERSION_A)
            .expect("manifest should be written");
        fs::write(frontend.path().join("index.html"), "<!doctype html>")
            .expect("index should be written");
        fs::write(frontend.path().join(format!("app-{VERSION_A}.js")), "")
            .expect("asset should be written");
        let frontend_version = FrontendVersion::new(frontend.path().join("frontend-version"));
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
                    .uri(format!("/app-{VERSION_A}.js"))
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
