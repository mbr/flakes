{ appModule }:

{
  name = "myapp-caddy-unix-listener";
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
    machine.fail("systemctl status myapp.socket")

    after = machine.succeed("systemctl show myapp.service --property=After --value").split()
    requires = machine.succeed("systemctl show myapp.service --property=Requires --value").split()
    assert "postgresql-setup.service" in after
    assert "postgresql-setup.service" in requires

    machine.wait_until_succeeds("curl --fail --silent http://localhost/api/status")
    machine.succeed("curl --fail --silent http://localhost/")

    machine.succeed("test $(stat --format=%a /run/myapp/http.sock) = 770")
    machine.succeed("test $(stat --format=%G /run/myapp/http.sock) = myapp-service")

    socket_inode = machine.succeed("stat --format=%i /run/myapp/http.sock").strip()
    machine.succeed("systemctl stop myapp.service")
    machine.wait_until_fails("systemctl is-active --quiet myapp.service")
    machine.succeed("test ! -e /run/myapp/http.sock")

    machine.succeed(
        "systemd-run --unit=myapp-delayed-start --on-active=2s "
        "/run/current-system/sw/bin/systemctl start myapp.service"
    )
    machine.succeed("curl --fail --silent http://localhost/api/status")
    machine.wait_for_unit("myapp.service")
    assert machine.succeed("stat --format=%i /run/myapp/http.sock").strip() != socket_inode
  '';
}
