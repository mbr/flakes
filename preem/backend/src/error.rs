//! Defines failures retained inside the application.
//!
//! [`AppError`] is never serialized or returned from HTTP handlers. Handlers
//! convert it into [`crate::api::ApiProblem`], which explicitly controls what
//! reaches the client.

use thiserror::Error;

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
