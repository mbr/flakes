{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.myapp;
  system = pkgs.stdenv.hostPlatform.system;
  isUnixSocket = lib.hasPrefix "/" cfg.listenAddress;
  socketDirectory = builtins.dirOf cfg.listenAddress;
  runtimeDirectory = lib.removePrefix "/run/" socketDirectory;
  tcpPortMatch = builtins.match "^.*:([0-9]+)$" cfg.listenAddress;
  tcpPort = if tcpPortMatch == null then null else lib.toInt (lib.head tcpPortMatch);
  databaseUrl =
    if cfg.database.createLocally then
      "postgresql:///${cfg.database.name}?host=/run/postgresql"
    else
      cfg.database.url;
  logFilter =
    "myapp=${cfg.logLevel},tower_http=${cfg.logLevel}"
    + lib.optionalString (cfg.extraLogFilters != "") ",${cfg.extraLogFilters}";
  configurationFile = (pkgs.formats.toml { }).generate "myapp.toml" {
    listen_address = cfg.listenAddress;
    database_url = databaseUrl;
    frontend = "${cfg.package}/share/myapp/frontend";
    log_filter = logFilter;
  };
in
{
  options.services.myapp = {
    enable = lib.mkEnableOption "myapp web service";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.default;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "Application package to run.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "myapp";
      description = "User under which the application runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = cfg.user;
      defaultText = lib.literalExpression "config.services.myapp.user";
      description = "Group under which the application runs.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3000";
      example = "/run/myapp/http.sock";
      description = "TCP socket address or absolute Unix socket path on which the application listens.";
    };

    socketGroup = lib.mkOption {
      type = lib.types.str;
      default = "myapp-proxy";
      description = "Group permitted to connect to a Unix listener.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the application port in the firewall.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "error"
        "warn"
        "info"
        "debug"
        "trace"
      ];
      default = "info";
      description = "Application log verbosity.";
    };

    extraLogFilters = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "sqlx=warn,tower_http=debug";
      description = "Additional tracing filters appended to the application defaults.";
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to provision a local PostgreSQL database.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "myapp";
        description = "Name of the local PostgreSQL database.";
      };

      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PostgreSQL URL used when local provisioning is disabled.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.database.createLocally || cfg.database.url != null;
        message = "services.myapp.database.url must be set when local database provisioning is disabled";
      }
      {
        assertion = isUnixSocket || tcpPort != null;
        message = "services.myapp.listenAddress must be a TCP socket address or absolute Unix socket path";
      }
      {
        assertion = !isUnixSocket || lib.hasPrefix "/run/" socketDirectory;
        message = "services.myapp.listenAddress Unix socket must be inside a subdirectory of /run";
      }
      {
        assertion = !isUnixSocket || !cfg.openFirewall;
        message = "services.myapp.openFirewall cannot be enabled with a Unix listener";
      }
      {
        assertion = !isUnixSocket || cfg.user != cfg.socketGroup;
        message = "services.myapp.socketGroup must differ from the dynamic service user";
      }
    ];

    users.groups.${cfg.socketGroup} = lib.mkIf isUnixSocket { };

    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.user;
          ensureDBOwnership = true;
        }
      ];
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf (cfg.openFirewall && !isUnixSocket && tcpPort != null)
        [
          tcpPort
        ];

    systemd.services.myapp = {
      description = "myapp web service";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ] ++ lib.optional cfg.database.createLocally "postgresql.service";
      requires = lib.optional cfg.database.createLocally "postgresql.service";

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} ${configurationFile}";
        User = cfg.user;
        Group = if isUnixSocket then cfg.socketGroup else cfg.group;
        DynamicUser = true;
        RuntimeDirectory = lib.mkIf isUnixSocket runtimeDirectory;
        RuntimeDirectoryMode = lib.mkIf isUnixSocket "0750";
        Restart = "on-failure";
        RestartSec = "5s";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
        UMask = "0077";
      };
    };
  };
}
