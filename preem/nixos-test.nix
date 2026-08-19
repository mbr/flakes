{ appModule }:

{
  name = "myapp-caddy-restart-retry";
  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ appModule ];
      services.myapp = {
        enable = true;
        caddy = {
          enable = true;
          virtualHost = "http://localhost";
        };
      };
      environment.systemPackages = [ pkgs.curl ];
      system.stateVersion = "26.05";
    };
  testScript = ''
    start_all()
    machine.wait_for_unit("myapp.service")
    machine.wait_for_unit("caddy.service")

    after = machine.succeed("systemctl show myapp.service --property=After --value").split()
    requires = machine.succeed("systemctl show myapp.service --property=Requires --value").split()
    assert "postgresql-setup.service" in after
    assert "postgresql-setup.service" in requires

    machine.fail("systemctl cat myapp.socket")
    machine.wait_until_succeeds("curl --fail --silent http://localhost/api/status")
    machine.succeed("curl --fail --silent http://localhost/")
    machine.succeed("curl --fail --silent http://127.0.0.1:3000/api/status")

    machine.succeed("systemctl stop myapp.service")
    machine.wait_until_fails("systemctl is-active --quiet myapp.service")
    machine.succeed(
      "systemd-run --unit=start-myapp --on-active=2s systemctl start myapp.service"
    )
    machine.succeed("curl --fail --silent http://localhost/api/status")
    machine.wait_for_unit("myapp.service")
  '';
}
