{ self, nixdrawer }:
{ lib, ... }:
{
  imports = [
    (nixdrawer.lib.mkWebAppModule {
      name = "myapp";
      description = "myapp web service";
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
            "myapp=${cfg.logLevel},tower_http=${cfg.logLevel}"
            + lib.optionalString (cfg.extraLogFilters != "") ",${cfg.extraLogFilters}";
          configurationFile = (pkgs.formats.toml { }).generate "myapp.toml" {
            listen_address = listenAddress;
            database_url = databaseUrl;
            frontend = "${package}/share/myapp/frontend";
            log_filter = logFilter;
          };
        in
        [
          (lib.getExe package)
          configurationFile
        ];
    })
  ];

  options.services.myapp = {
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
