//! Defines public values sent across the HTTP boundary.
//!
//! Successful handlers serialize their endpoint-specific response types.
//! Non-success responses serialize [`ApiProblem`], whose variants and payloads
//! must remain synchronized with `frontend/src/Api.elm`. Internal failures and
//! private context belong in `error.rs`, not in these serializable types.

use axum::http::StatusCode;
use serde::Serialize;

/// Describes a successful status response.
#[derive(Debug, Serialize)]
pub struct StatusResponse {
    /// Current service status.
    pub status: &'static str,

    /// Whether the database accepted the status query.
    pub database_ready: bool,
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

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::{ApiProblem, StatusResponse};

    /// Verifies the initial cross-language transport contract.
    #[test]
    fn serializes_api_values() {
        let response = StatusResponse {
            status: "ok",
            database_ready: true,
        };

        assert_eq!(
            serde_json::to_value(response).expect("status response should serialize"),
            json!({ "status": "ok", "database_ready": true }),
        );
        assert_eq!(
            serde_json::to_value(ApiProblem::RouteNotFound).expect("API problem should serialize"),
            json!({ "type": "route_not_found" }),
        );
    }
}
