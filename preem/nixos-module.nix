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
  databaseUrl =
    if cfg.database.createLocally then
      "postgresql:///${cfg.database.name}?host=/run/postgresql"
    else
      cfg.database.url;
  logFilter =
    "myapp=${cfg.logLevel},tower_http=${cfg.logLevel}"
    + lib.optionalString (cfg.extraLogFilters != "") ",${cfg.extraLogFilters}";
  configurationFile = (pkgs.formats.toml { }).generate "myapp.toml" {
    bind_address = cfg.bindAddress;
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

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3000";
      description = "Socket address on which the application listens.";
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
    ];

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

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      (lib.toInt (lib.last (lib.splitString ":" cfg.bindAddress)))
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
        Group = cfg.group;
        DynamicUser = true;
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
