//! Defines failures retained inside the application.
//!
//! Handlers return [`AppResult`] so `?` can preserve source errors through
//! conversions into [`AppError`]. [`AppError`] is never serialized: its
//! [`IntoResponse`] implementation is the terminal boundary where private
//! details remain available for logging before mapping to [`ApiProblem`].

use axum::{
    Json,
    response::{IntoResponse, Response},
};
use thiserror::Error;

use crate::api::ApiProblem;

/// Represents the result returned by HTTP handlers.
pub type AppResult<T> = Result<T, AppError>;

/// Describes failures retained for application code and diagnostics.
#[derive(Debug, Error)]
pub enum AppError {
    /// The requested API route does not exist.
    #[error("API route not found")]
    RouteNotFound,

    /// The API route does not accept the request method.
    #[error("API method not allowed")]
    MethodNotAllowed,
}

impl AppError {
    /// Converts an internal failure into its safe public representation.
    fn into_problem(self) -> ApiProblem {
        match self {
            Self::RouteNotFound => ApiProblem::RouteNotFound,
            Self::MethodNotAllowed => ApiProblem::MethodNotAllowed,
        }
    }
}

impl IntoResponse for AppError {
    /// Maps an internal failure to a non-success HTTP response.
    ///
    /// Log the complete internal error here when the application adds failures
    /// that warrant a dedicated event. Request status and latency remain the
    /// responsibility of the HTTP tracing middleware.
    fn into_response(self) -> Response {
        let problem = self.into_problem();
        (problem.status_code(), Json(problem)).into_response()
    }
}
