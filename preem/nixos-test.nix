{ appModule }:

{
  name = "myapp-caddy-socket-activation";
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
    machine.wait_for_unit("myapp.socket")
    machine.wait_for_unit("myapp.service")
    machine.wait_for_unit("caddy.service")

    machine.wait_until_succeeds("curl --fail --silent http://localhost/api/status")
    machine.succeed("curl --fail --silent http://localhost/")

    machine.succeed("test $(stat --format=%a /run/myapp/http.sock) = 660")
    machine.succeed("test $(stat --format=%G /run/myapp/http.sock) = myapp-proxy")

    socket_inode = machine.succeed("stat --format=%i /run/myapp/http.sock").strip()
    machine.succeed("systemctl stop myapp.service")
    machine.wait_until_fails("systemctl is-active --quiet myapp.service")
    machine.succeed("systemctl is-active --quiet myapp.socket")
    assert machine.succeed("stat --format=%i /run/myapp/http.sock").strip() == socket_inode

    machine.succeed("curl --fail --silent http://localhost/api/status")
    machine.wait_for_unit("myapp.service")
    assert machine.succeed("stat --format=%i /run/myapp/http.sock").strip() == socket_inode
  '';
}
