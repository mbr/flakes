//! Opens directly bound or inherited HTTP listeners.

use std::{
    fs, io,
    net::SocketAddr,
    os::unix::{fs::PermissionsExt, net::UnixListener as StdUnixListener},
    path::{Path, PathBuf},
};

use listenfd::ListenFd;
use thiserror::Error;
use tokio::net::{TcpListener, UnixListener};

use crate::config::ListenAddress;

/// Provides an HTTP listener supported by Axum.
pub enum Listener {
    /// Provides a TCP listener.
    Tcp(TcpListener),

    /// Provides a Unix-domain listener.
    Unix(UnixListener),
}

/// Describes failures while opening an HTTP listener.
#[derive(Debug, Error)]
pub enum OpenError {
    /// More than one inherited descriptor was supplied.
    #[error("expected at most one inherited listening descriptor, received {count}")]
    TooManyInherited {
        /// Number of descriptors supplied by the service manager.
        count: usize,
    },

    /// An inherited descriptor was not a TCP listener.
    #[error("failed to receive inherited TCP listener")]
    InheritedTcp {
        /// Underlying descriptor validation error.
        #[source]
        source: io::Error,
    },

    /// An inherited descriptor was not a Unix listener.
    #[error("failed to receive inherited Unix listener")]
    InheritedUnix {
        /// Underlying descriptor validation error.
        #[source]
        source: io::Error,
    },

    /// An inherited TCP listener address could not be read.
    #[error("failed to read inherited TCP listener address")]
    InheritedTcpAddress {
        /// Underlying socket error.
        #[source]
        source: io::Error,
    },

    /// An inherited Unix listener address could not be read.
    #[error("failed to read inherited Unix listener address")]
    InheritedUnixAddress {
        /// Underlying socket error.
        #[source]
        source: io::Error,
    },

    /// An inherited TCP listener does not match the configuration.
    #[error("inherited TCP listener address {actual} does not match configured address {expected}")]
    TcpAddressMismatch {
        /// Address declared by the application configuration.
        expected: SocketAddr,

        /// Address bound by the service manager.
        actual: SocketAddr,
    },

    /// An inherited Unix listener has no filesystem path.
    #[error("inherited Unix listener does not have a filesystem path")]
    UnnamedUnix,

    /// An inherited Unix listener does not match the configuration.
    #[error("inherited Unix listener path {actual} does not match configured path {expected}")]
    UnixAddressMismatch {
        /// Path declared by the application configuration.
        expected: PathBuf,

        /// Path bound by the service manager.
        actual: PathBuf,
    },

    /// An inherited listener could not be configured for Tokio.
    #[error("failed to configure inherited listener as nonblocking")]
    ConfigureInherited {
        /// Underlying socket error.
        #[source]
        source: io::Error,
    },

    /// A directly managed TCP listener could not be bound.
    #[error("failed to bind TCP listener at {address}")]
    BindTcp {
        /// Configured listener address.
        address: SocketAddr,

        /// Underlying socket error.
        #[source]
        source: io::Error,
    },

    /// A directly managed Unix listener could not be bound.
    #[error("failed to bind Unix listener at {path}")]
    BindUnix {
        /// Configured listener path.
        path: PathBuf,

        /// Underlying socket error.
        #[source]
        source: io::Error,
    },

    /// A directly managed Unix listener could not be made group-accessible.
    #[error("failed to set permissions on Unix listener at {path}")]
    SetUnixPermissions {
        /// Configured listener path.
        path: PathBuf,

        /// Underlying filesystem error.
        #[source]
        source: io::Error,
    },
}

/// Opens the configured listener or consumes one supplied by a service manager.
pub async fn open(address: &ListenAddress) -> Result<Listener, OpenError> {
    let mut inherited = ListenFd::from_env();

    if inherited.len() > 1 {
        return Err(OpenError::TooManyInherited {
            count: inherited.len(),
        });
    }

    match address {
        ListenAddress::Tcp(address) => open_tcp(*address, &mut inherited).await,
        ListenAddress::Unix(path) => open_unix(path, &mut inherited),
    }
}

/// Opens a directly bound or inherited TCP listener.
async fn open_tcp(address: SocketAddr, inherited: &mut ListenFd) -> Result<Listener, OpenError> {
    let Some(listener) = inherited
        .take_tcp_listener(0)
        .map_err(|source| OpenError::InheritedTcp { source })?
    else {
        return TcpListener::bind(address)
            .await
            .map(Listener::Tcp)
            .map_err(|source| OpenError::BindTcp { address, source });
    };

    let actual = listener
        .local_addr()
        .map_err(|source| OpenError::InheritedTcpAddress { source })?;
    if actual != address {
        return Err(OpenError::TcpAddressMismatch {
            expected: address,
            actual,
        });
    }

    listener
        .set_nonblocking(true)
        .map_err(|source| OpenError::ConfigureInherited { source })?;

    TcpListener::from_std(listener)
        .map(Listener::Tcp)
        .map_err(|source| OpenError::ConfigureInherited { source })
}

/// Opens a directly bound or inherited Unix listener.
fn open_unix(path: &Path, inherited: &mut ListenFd) -> Result<Listener, OpenError> {
    let Some(listener) = inherited
        .take_unix_listener(0)
        .map_err(|source| OpenError::InheritedUnix { source })?
    else {
        let listener = UnixListener::bind(path).map_err(|source| OpenError::BindUnix {
            path: path.to_path_buf(),
            source,
        })?;
        fs::set_permissions(path, fs::Permissions::from_mode(0o660)).map_err(|source| {
            OpenError::SetUnixPermissions {
                path: path.to_path_buf(),
                source,
            }
        })?;
        return Ok(Listener::Unix(listener));
    };

    validate_unix_address(path, &listener)?;
    listener
        .set_nonblocking(true)
        .map_err(|source| OpenError::ConfigureInherited { source })?;

    UnixListener::from_std(listener)
        .map(Listener::Unix)
        .map_err(|source| OpenError::ConfigureInherited { source })
}

/// Validates the path of an inherited Unix listener.
fn validate_unix_address(path: &Path, listener: &StdUnixListener) -> Result<(), OpenError> {
    let address = listener
        .local_addr()
        .map_err(|source| OpenError::InheritedUnixAddress { source })?;
    let actual = address
        .as_pathname()
        .map(PathBuf::from)
        .ok_or(OpenError::UnnamedUnix)?;

    if actual != path {
        return Err(OpenError::UnixAddressMismatch {
            expected: path.to_path_buf(),
            actual,
        });
    }

    Ok(())
}
