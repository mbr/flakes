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
      default = "myapp";
      description = "Group under which the application runs.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3000";
      description = "Socket address on which the application listens.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    systemd.services.myapp = {
      description = "myapp web service";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = {
        APP_BIND_ADDRESS = cfg.bindAddress;
        RUST_LOG = "myapp=info,tower_http=info";
      };

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        User = cfg.user;
        Group = cfg.group;
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
