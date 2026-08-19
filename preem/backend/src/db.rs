//! Provides PostgreSQL connection management and checked queries.

use sqlx::{
    PgConnection, PgPool,
    migrate::{MigrateError, Migrator},
    postgres::PgPoolOptions,
};
use thiserror::Error;
use twelve::config::DatabaseUrl;

/// Embedded database migrations.
static MIGRATOR: Migrator = sqlx::migrate!();

/// Describes the database status returned to the web layer.
#[derive(Debug)]
pub struct DatabaseStatus {
    /// Whether the database accepted the status query.
    pub ready: bool,
}

/// Describes failures while opening the database.
#[derive(Debug, Error)]
pub enum OpenError {
    /// A PostgreSQL connection could not be established.
    #[error("failed to connect to PostgreSQL")]
    Connect {
        /// Underlying SQLx error.
        #[source]
        source: sqlx::Error,
    },

    /// Database migrations could not be applied.
    #[error("failed to migrate PostgreSQL")]
    Migrate {
        /// Underlying migration error.
        #[source]
        source: MigrateError,
    },
}

/// Opens the PostgreSQL connection pool and applies migrations.
pub async fn connect(database_url: DatabaseUrl) -> Result<PgPool, OpenError> {
    let pool = PgPoolOptions::new()
        .connect_with(database_url.into_connect_options())
        .await
        .map_err(|source| OpenError::Connect { source })?;

    MIGRATOR
        .run(&pool)
        .await
        .map_err(|source| OpenError::Migrate { source })?;

    Ok(pool)
}

/// Checks the database with a compile-time checked query.
pub async fn status(connection: &mut PgConnection) -> Result<DatabaseStatus, sqlx::Error> {
    sqlx::query_as!(
        DatabaseStatus,
        r#"
        SELECT EXISTS (
            SELECT 1
            FROM application_metadata
            WHERE id = TRUE
        ) AS "ready!"
        "#,
    )
    .fetch_one(connection)
    .await
}
