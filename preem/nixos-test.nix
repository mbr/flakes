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
    import re

    start_all()
    machine.wait_for_unit("myapp.socket")
    machine.wait_for_unit("myapp.service")
    machine.wait_for_unit("caddy.service")
    machine.wait_until_succeeds("curl --fail --silent http://localhost/api/status")
    machine.wait_until_succeeds(
        "curl --fail --silent --unix-socket /run/myapp/http.sock http://localhost/api/status"
    )

    api_headers = machine.succeed(
        "curl --fail --silent --dump-header - --output /dev/null "
        "--unix-socket /run/myapp/http.sock http://localhost/api/status"
    )
    assert re.search(r"(?im)^frontend-version: [0-9a-f]{64}\r?$", api_headers)

    index_headers = machine.succeed(
        "curl --fail --silent --dump-header - --output /dev/null "
        "--unix-socket /run/myapp/http.sock http://localhost/"
    )
    assert re.search(r"(?im)^cache-control: no-cache\r?$", index_headers)

    index = machine.succeed(
        "curl --fail --silent --unix-socket /run/myapp/http.sock http://localhost/"
    )
    asset_match = re.search(r"app-[0-9a-f]{64}\.js", index)
    assert asset_match is not None
    asset = asset_match.group(0)
    asset_headers = machine.succeed(
        f"curl --fail --silent --dump-header - --output /dev/null "
        f"--unix-socket /run/myapp/http.sock http://localhost/{asset}"
    )
    assert re.search(
        r"(?im)^cache-control: public, max-age=31536000, immutable\r?$",
        asset_headers,
    )

    machine.succeed("test $(stat --format=%a /run/myapp/http.sock) = 660")
    machine.succeed("test $(stat --format=%G /run/myapp/http.sock) = myapp-proxy")

    socket_inode = machine.succeed("stat --format=%i /run/myapp/http.sock").strip()
    machine.succeed("systemctl restart myapp.service")
    machine.wait_for_unit("myapp.service")
    assert machine.succeed("stat --format=%i /run/myapp/http.sock").strip() == socket_inode
    machine.succeed(
        "curl --fail --silent --unix-socket /run/myapp/http.sock http://localhost/api/status"
    )
  '';
}
