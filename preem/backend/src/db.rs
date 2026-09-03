//! Provides checked PostgreSQL queries.

use sqlx::PgConnection;

/// Describes the database status returned to the web layer.
#[derive(Debug)]
pub struct DatabaseStatus {
    /// Whether the database accepted the status query.
    pub ready: bool,
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
