{
  self,
  nixdrawer,
  name,
}:
{ lib, ... }:
let
  logTarget = lib.replaceStrings [ "-" ] [ "_" ] name;
in
{
  imports = [
    (nixdrawer.lib.mkWebAppModule {
      inherit name;
      description = "${name} web service";
      defaultPackage = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      mkCommand =
        {
          cfg,
          databaseUrl,
          lib,
          listenAddress,
          package,
          pkgs,
        }:
        let
          logFilter =
            "${logTarget}=${cfg.logLevel},tower_http=${cfg.logLevel}"
            + lib.optionalString (cfg.extraLogFilters != "") ",${cfg.extraLogFilters}";
          configurationFile = (pkgs.formats.toml { }).generate "${name}.toml" {
            listen_address = listenAddress;
            # SQLx needs an explicit user for local peer authentication.
            database_url =
              databaseUrl + lib.optionalString cfg.database.createLocally "&user=${lib.escapeURL cfg.user}";
            frontend = "${package}/share/${name}/frontend";
            log_filter = logFilter;
          };
        in
        [
          (lib.getExe package)
          configurationFile
        ];
    })
  ];

  options.services.${name} = {
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
  };
}
