{ appModule, name }:

{
  name = "${name}-caddy-unix-listener";
  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ appModule ];
      services.caddy.enable = true;
      services.${name} = {
        enable = true;
        caddy.virtualHost = "http://localhost";
      };
      environment.systemPackages = [ pkgs.curl ];
      system.stateVersion = "26.05";
    };
  testScript = ''
    start_all()
    machine.wait_for_unit("${name}.service")
    machine.wait_for_unit("caddy.service")
    machine.fail("systemctl status ${name}.socket")
    assert machine.succeed("systemctl show ${name}.service --property=Type --value").strip() == "exec"

    after = machine.succeed("systemctl show ${name}.service --property=After --value").split()
    requires = machine.succeed("systemctl show ${name}.service --property=Requires --value").split()
    assert "postgresql-setup.service" in after
    assert "postgresql-setup.service" in requires

    machine.wait_until_succeeds("curl --fail --silent http://localhost/api/ping")
    machine.succeed("curl --fail --silent http://localhost/")

    machine.succeed("test $(stat --format=%a /run/${name}/http.sock) = 770")
    machine.succeed("test $(stat --format=%G /run/${name}/http.sock) = ${name}-service")

    socket_inode = machine.succeed("stat --format=%i /run/${name}/http.sock").strip()
    machine.succeed("systemctl stop ${name}.service")
    machine.wait_until_fails("systemctl is-active --quiet ${name}.service")
    machine.succeed("test ! -e /run/${name}/http.sock")

    machine.succeed(
        "systemd-run --unit=${name}-delayed-start --on-active=2s "
        "/run/current-system/sw/bin/systemctl start ${name}.service"
    )
    machine.wait_until_succeeds("curl --fail --silent http://localhost/api/ping")
    machine.wait_for_unit("${name}.service")
    assert machine.succeed("stat --format=%i /run/${name}/http.sock").strip() != socket_inode
  '';
}
