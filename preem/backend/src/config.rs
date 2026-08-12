//! Loads application configuration from TOML.

use std::{
    fs,
    net::{AddrParseError, SocketAddr},
    path::{Path, PathBuf},
    str::FromStr,
};

use serde::Deserialize;
use thiserror::Error;

use crate::db::DatabaseUrl;

/// Identifies an HTTP listener.
#[derive(Debug, Deserialize, Eq, PartialEq)]
#[serde(try_from = "String")]
pub enum ListenAddress {
    /// Listens on a TCP socket.
    Tcp(SocketAddr),

    /// Listens on a Unix-domain socket.
    Unix(PathBuf),
}

impl FromStr for ListenAddress {
    type Err = ParseListenAddressError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        if value.starts_with('/') {
            Ok(Self::Unix(PathBuf::from(value)))
        } else {
            value
                .parse()
                .map(Self::Tcp)
                .map_err(|source| ParseListenAddressError { source })
        }
    }
}

impl TryFrom<String> for ListenAddress {
    type Error = ParseListenAddressError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        value.parse()
    }
}

/// Describes an invalid HTTP listener address.
#[derive(Debug, Error)]
#[error("expected a TCP socket address or absolute Unix socket path")]
pub struct ParseListenAddressError {
    /// Underlying TCP socket address error.
    #[source]
    source: AddrParseError,
}

/// Configures the web application.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    /// Address on which the HTTP server listens.
    pub listen_address: ListenAddress,

    /// PostgreSQL connection URL.
    pub database_url: DatabaseUrl,

    /// Directory containing the built frontend.
    pub frontend: PathBuf,

    /// Tracing filter applied by the application.
    pub log_filter: String,
}

/// Describes failures while loading application configuration.
#[derive(Debug, Error)]
pub enum LoadError {
    /// The configuration file could not be read.
    #[error("failed to read configuration from {path}")]
    Read {
        /// Path to the configuration file.
        path: PathBuf,

        /// Underlying filesystem error.
        #[source]
        source: std::io::Error,
    },

    /// The configuration file contains invalid TOML or values.
    #[error("failed to parse configuration from {path}")]
    Parse {
        /// Path to the configuration file.
        path: PathBuf,

        /// Underlying TOML error.
        #[source]
        source: toml::de::Error,
    },
}

/// Loads application configuration from a TOML file.
pub fn load(path: &Path) -> Result<Config, LoadError> {
    let serialized = fs::read_to_string(path).map_err(|source| LoadError::Read {
        path: path.to_owned(),
        source,
    })?;

    toml::from_str(&serialized).map_err(|source| LoadError::Parse {
        path: path.to_owned(),
        source,
    })
}

#[cfg(test)]
mod tests {
    use std::{net::SocketAddr, path::PathBuf};

    use super::ListenAddress;

    /// Parses each supported listener address family.
    #[test]
    fn parses_listener_addresses() {
        let ipv4: ListenAddress = "127.0.0.1:3000"
            .parse()
            .expect("IPv4 listener should parse");
        let ipv6: ListenAddress = "[::1]:3000".parse().expect("IPv6 listener should parse");
        let unix: ListenAddress = "/run/myapp/http.sock"
            .parse()
            .expect("Unix listener should parse");

        assert_eq!(
            ipv4,
            ListenAddress::Tcp(SocketAddr::from(([127, 0, 0, 1], 3000)))
        );
        assert_eq!(
            ipv6,
            ListenAddress::Tcp(SocketAddr::from(([0, 0, 0, 0, 0, 0, 0, 1], 3000)))
        );
        assert_eq!(
            unix,
            ListenAddress::Unix(PathBuf::from("/run/myapp/http.sock"))
        );
    }

    /// Rejects relative Unix socket paths.
    #[test]
    fn rejects_relative_unix_socket_path() {
        assert!("myapp.sock".parse::<ListenAddress>().is_err());
    }
}
