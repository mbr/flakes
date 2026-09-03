//! Serves the JSON API and compiled frontend.

use std::path::PathBuf;

use axum::{Json, Router, routing::get};
use sqlx::PgPool;
use tower_http::{services::ServeDir, trace::TraceLayer};
use twelve::frontend::RouterExt;

use crate::api::{ApiProblem, Pong};

/// Builds the application router.
pub(crate) fn router(frontend: PathBuf, database: PgPool) -> Router {
    let api = Router::new()
        .route("/ping", get(ping))
        .fallback(|| async { ApiProblem::RouteNotFound })
        .method_not_allowed_fallback(|| async { ApiProblem::MethodNotAllowed })
        .with_frontend_version(&frontend);

    let frontend = Router::new()
        .fallback_service(ServeDir::new(frontend).append_index_html_on_directories(true))
        .with_frontend_cache();

    Router::new()
        .nest("/api", api)
        .merge(frontend)
        .layer(TraceLayer::new_for_http())
        .with_state(database)
}

/// Responds to an API ping.
async fn ping() -> Json<Pong> {
    Json(Pong { message: "pong" })
}
