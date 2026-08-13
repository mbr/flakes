//! Adds the served frontend version to HTTP responses.

use std::{
    fs,
    path::{Path, PathBuf},
};

use axum::{
    extract::{Request, State},
    http::HeaderValue,
    middleware::Next,
    response::Response,
};

/// Name of the response header containing the frontend version.
const HEADER_NAME: &str = "frontend-version";

/// Holds the path to the generated frontend version manifest.
#[derive(Clone)]
pub struct FrontendVersion {
    /// Path read for each response.
    manifest: PathBuf,
}

impl FrontendVersion {
    /// Constructs middleware state for a frontend version manifest.
    pub fn new(manifest: PathBuf) -> Self {
        Self { manifest }
    }
}

/// Adds the current frontend version when its manifest is available and valid.
pub async fn attach(
    State(frontend_version): State<FrontendVersion>,
    request: Request,
    next: Next,
) -> Response {
    let version = match read(&frontend_version.manifest) {
        Ok(version) => Some(version),
        Err(error) => {
            tracing::warn!(
                %error,
                manifest = %frontend_version.manifest.display(),
                "failed to read frontend version"
            );
            None
        }
    };
    let mut response = next.run(request).await;

    if let Some(version) = version {
        response.headers_mut().insert(HEADER_NAME, version);
    }

    response
}

/// Reads the generated frontend version manifest as a header value.
fn read(manifest: &Path) -> std::io::Result<HeaderValue> {
    fs::read_to_string(manifest)?
        .trim()
        .parse()
        .map_err(|source| std::io::Error::new(std::io::ErrorKind::InvalidData, source))
}

#[cfg(test)]
mod tests {
    use std::fs;

    use axum::{Router, body::Body, http::Request, middleware, routing::get};
    use tempfile::tempdir;
    use tower::ServiceExt;

    use super::{FrontendVersion, HEADER_NAME, attach};

    /// Versions used to verify that the manifest is read for each request.
    const VERSION_A: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const VERSION_B: &str = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

    /// Refreshes the header and omits it while the manifest is unavailable.
    #[tokio::test]
    async fn reads_manifest_for_each_request() {
        let directory = tempdir().expect("temporary directory should be created");
        let manifest = directory.path().join("frontend-version");
        fs::write(&manifest, VERSION_A).expect("initial manifest should be written");
        let application =
            Router::new()
                .route("/", get(|| async {}))
                .layer(middleware::from_fn_with_state(
                    FrontendVersion::new(manifest.clone()),
                    attach,
                ));

        let response = application
            .clone()
            .oneshot(request())
            .await
            .expect("initial request should complete");
        assert_eq!(response.headers()[HEADER_NAME], VERSION_A);

        fs::write(&manifest, VERSION_B).expect("updated manifest should be written");
        let response = application
            .clone()
            .oneshot(request())
            .await
            .expect("updated request should complete");
        assert_eq!(response.headers()[HEADER_NAME], VERSION_B);

        fs::remove_file(manifest).expect("manifest should be removed");
        let response = application
            .oneshot(request())
            .await
            .expect("request without manifest should complete");
        assert!(response.headers().get(HEADER_NAME).is_none());
    }

    /// Builds a request for the middleware test application.
    fn request() -> Request<Body> {
        Request::builder()
            .uri("/")
            .body(Body::empty())
            .expect("request should be built")
    }
}
