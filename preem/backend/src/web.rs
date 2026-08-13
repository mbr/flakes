//! Serves the JSON API and compiled frontend.

use std::{
    fs, io,
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};

use axum::{
    Json, Router,
    extract::{Request, State},
    http::{HeaderValue, StatusCode, header::CACHE_CONTROL},
    middleware::{self, Next},
    response::Response,
    routing::get,
};
use sd_notify::NotifyState;
use sqlx::PgPool;
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::info;
use twelve::config::ListenAddress;

use crate::{
    api::StatusResponse,
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

/// Reads and retains the version of the served frontend.
#[derive(Clone)]
struct FrontendVersion {
    /// Path to the generated version manifest.
    manifest: PathBuf,

    /// Last valid version and manifest availability state.
    state: Arc<Mutex<FrontendVersionState>>,
}

/// Holds mutable frontend version state.
struct FrontendVersionState {
    /// Indicates whether a manifest read failure has already been logged.
    unavailable: bool,

    /// Last valid frontend version.
    value: HeaderValue,
}

impl FrontendVersion {
    /// Loads the initial frontend version from a built frontend directory.
    fn load(frontend: &Path) -> io::Result<Self> {
        let manifest = frontend.join("frontend-version");
        let value = read_frontend_version(&manifest)?;

        Ok(Self {
            manifest,
            state: Arc::new(Mutex::new(FrontendVersionState {
                unavailable: false,
                value,
            })),
        })
    }

    /// Returns the latest valid version while tolerating rebuild gaps.
    fn current(&self) -> HeaderValue {
        match read_frontend_version(&self.manifest) {
            Ok(value) => {
                let mut state = self
                    .state
                    .lock()
                    .expect("frontend version lock should not be poisoned");
                state.unavailable = false;
                state.value = value.clone();
                value
            }
            Err(error) => {
                let mut state = self
                    .state
                    .lock()
                    .expect("frontend version lock should not be poisoned");
                if !state.unavailable {
                    tracing::warn!(
                        %error,
                        manifest = %self.manifest.display(),
                        "failed to refresh frontend version"
                    );
                }
                state.unavailable = true;
                state.value.clone()
            }
        }
    }
}

/// Reads and validates a generated frontend version manifest.
fn read_frontend_version(manifest: &Path) -> io::Result<HeaderValue> {
    let serialized = fs::read_to_string(manifest)?;
    let version = serialized.trim();
    let valid = version.len() == 64
        && version
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte));

    if !valid {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "frontend version must be a lowercase SHA-256 digest",
        ));
    }

    version
        .parse()
        .map_err(|source| io::Error::new(io::ErrorKind::InvalidData, source))
}

/// Runs the HTTP server.
pub async fn run(
    listen_address: ListenAddress,
    frontend: PathBuf,
    database: PgPool,
) -> anyhow::Result<()> {
    let frontend_version = FrontendVersion::load(&frontend)?;
    let application = router(frontend.clone(), database, frontend_version);
    let shutdown = twelve::shutdown_signal();

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

/// Builds the application router.
fn router(frontend: PathBuf, database: PgPool, frontend_version: FrontendVersion) -> Router {
    let api = Router::new()
        .route("/status", get(status))
        .fallback(api_not_found)
        .method_not_allowed_fallback(method_not_allowed)
        .layer(middleware::from_fn_with_state(
            frontend_version,
            attach_frontend_version,
        ));

    Router::new()
        .nest("/api", api)
        .fallback_service(ServeDir::new(frontend))
        .layer(middleware::from_fn(set_frontend_cache_policy))
        .layer(TraceLayer::new_for_http())
        .with_state(AppState { database })
}

/// Attaches the currently served frontend version to an API response.
async fn attach_frontend_version(
    State(frontend_version): State<FrontendVersion>,
    request: Request,
    next: Next,
) -> Response {
    let version = frontend_version.current();
    let mut response = next.run(request).await;
    response.headers_mut().insert("frontend-version", version);
    response
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

    use super::{FrontendVersion, is_fingerprinted_asset, router};

    /// First frontend version used by the tests.
    const VERSION_A: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    /// Second frontend version used by the tests.
    const VERSION_B: &str = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

    /// Refreshes the frontend version and retains it across manifest gaps.
    #[test]
    fn refreshes_frontend_version() {
        let frontend = tempdir().expect("temporary frontend should be created");
        let manifest = frontend.path().join("frontend-version");
        fs::write(&manifest, VERSION_A).expect("initial manifest should be written");
        let version = FrontendVersion::load(frontend.path()).expect("frontend version should load");

        assert_eq!(version.current(), VERSION_A);

        fs::write(&manifest, VERSION_B).expect("updated manifest should be written");
        assert_eq!(version.current(), VERSION_B);

        fs::remove_file(manifest).expect("manifest should be removed");
        assert_eq!(version.current(), VERSION_B);
    }

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
        let frontend_version =
            FrontendVersion::load(frontend.path()).expect("frontend version should load");
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
