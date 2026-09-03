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

impl IntoResponse for ApiProblem {
    /// Serializes the problem as a non-success HTTP response.
    fn into_response(self) -> Response {
        let status = self.status_code();
        (status, Json(self)).into_response()
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::{ApiProblem, Pong};

    /// Verifies the initial cross-language transport contract.
    #[test]
    fn serializes_api_values() {
        let response = Pong { message: "pong" };

        assert_eq!(
            serde_json::to_value(response).expect("pong response should serialize"),
            json!({ "message": "pong" }),
        );
        assert_eq!(
            serde_json::to_value(ApiProblem::RouteNotFound).expect("API problem should serialize"),
            json!({ "type": "route_not_found" }),
        );
    }
}
