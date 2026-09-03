//! Defines failures retained inside the application.
//!
//! Handlers return [`AppResult`] so `?` can preserve source errors through
//! conversions into [`AppError`]. [`AppError`] is never serialized: its
//! [`IntoResponse`] implementation is the terminal boundary where private
//! details remain available for logging before mapping to [`ApiProblem`].

use axum::response::{IntoResponse, Response};
use thiserror::Error;

use crate::api::ApiProblem;

/// Represents the result returned by HTTP handlers.
pub type AppResult<T> = Result<T, AppError>;

/// Describes failures retained for application code and diagnostics.
#[derive(Debug, Error)]
pub enum AppError {
    /// A database operation failed.
    #[error("database operation failed")]
    Database {
        /// Underlying SQLx error.
        #[from]
        source: sqlx::Error,
    },
}

impl AppError {
    /// Converts an internal failure into its safe public representation.
    fn into_problem(self) -> ApiProblem {
        match self {
            Self::Database { .. } => ApiProblem::Internal,
        }
    }
}

impl IntoResponse for AppError {
    /// Maps an internal failure to a non-success HTTP response.
    ///
    /// Unexpected failures are logged with private context. Request status and
    /// latency remain the responsibility of the HTTP tracing middleware.
    fn into_response(self) -> Response {
        tracing::error!(error = ?self, "request failed");
        self.into_problem().into_response()
    }
}
