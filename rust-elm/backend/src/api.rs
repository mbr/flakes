//! Defines the HTTP transport contract and its error representation.

use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use thiserror::Error;

/// Describes a successful status response.
#[derive(Debug, Serialize)]
pub struct StatusResponse {
    /// Current service status.
    pub status: &'static str,
}

/// Describes an error returned by the JSON API.
#[derive(Debug, Serialize)]
struct Problem {
    /// Stable machine-readable error identity.
    code: &'static str,
    /// Human-readable error description.
    message: &'static str,
}

/// Describes failures exposed by the JSON API.
#[derive(Debug, Error)]
pub enum ApiError {
    /// The requested API route does not exist.
    #[error("API route not found")]
    RouteNotFound,

    /// The API route does not accept the request method.
    #[error("API method not allowed")]
    MethodNotAllowed,
}

impl ApiError {
    /// Returns the HTTP status associated with the error.
    const fn status(&self) -> StatusCode {
        match self {
            Self::RouteNotFound => StatusCode::NOT_FOUND,
            Self::MethodNotAllowed => StatusCode::METHOD_NOT_ALLOWED,
        }
    }

    /// Returns the stable machine-readable error identity.
    const fn code(&self) -> &'static str {
        match self {
            Self::RouteNotFound => "route_not_found",
            Self::MethodNotAllowed => "method_not_allowed",
        }
    }

    /// Returns the message safe to expose to clients.
    const fn public_message(&self) -> &'static str {
        match self {
            Self::RouteNotFound => "API route not found",
            Self::MethodNotAllowed => "API method not allowed",
        }
    }
}

impl IntoResponse for ApiError {
    /// Converts an API failure into a structured JSON response.
    fn into_response(self) -> Response {
        let status = self.status();
        let problem = Problem {
            code: self.code(),
            message: self.public_message(),
        };

        (status, Json(problem)).into_response()
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::StatusResponse;

    /// Verifies the initial cross-language status contract.
    #[test]
    fn serializes_status_response() {
        let response = StatusResponse { status: "ok" };
        let value = serde_json::to_value(response).expect("status response should serialize");

        assert_eq!(value, json!({ "status": "ok" }));
    }
}
