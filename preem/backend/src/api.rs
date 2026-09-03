//! Types sent over the wire between the Elm frontend and Rust backend.
//!
//! This file needs to be kept in sync with `frontend/src/Api.elm`. Successful
//! responses use endpoint-specific types, while non-success responses use the
//! shared [`ApiProblem`] type.

use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;

use crate::error::AppError;

/// Describes a successful ping response.
#[derive(Debug, Serialize)]
pub struct Pong {
    /// Contains the response to the ping request.
    pub message: &'static str,
}

/// Describes failures safe to expose through the JSON API.
#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ApiProblem {
    /// The server could not complete the request.
    Internal,

    /// The requested API route does not exist.
    RouteNotFound,

    /// The API route does not accept the request method.
    MethodNotAllowed,
}

impl ApiProblem {
    /// Returns the HTTP status associated with the public problem.
    pub const fn status_code(&self) -> StatusCode {
        match self {
            Self::Internal => StatusCode::INTERNAL_SERVER_ERROR,
            Self::RouteNotFound => StatusCode::NOT_FOUND,
            Self::MethodNotAllowed => StatusCode::METHOD_NOT_ALLOWED,
        }
    }
}

impl From<AppError> for ApiProblem {
    /// Converts an application failure into its safe public representation.
    fn from(error: AppError) -> Self {
        match error {
            error @ AppError::Database { .. } => {
                tracing::error!(error = ?error, "request failed");
                Self::Internal
            }
        }
    }
}

impl IntoResponse for ApiProblem {
    /// Serializes the problem as a non-success HTTP response.
    fn into_response(self) -> Response {
        let status = self.status_code();
        (status, Json(self)).into_response()
    }
}
