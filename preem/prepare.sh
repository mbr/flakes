#!/bin/sh

#: Refreshes SQLx query metadata against a temporary database.

set -eu

cd "$(dirname "$0")"

port=$(ephemeral-port-reserve)
database_url="postgres://dev:dev@127.0.0.1:$port/dev"

pgdb --port "$port" >/dev/null 2>&1 &
postgres_pid=$!
cleanup() {
  kill "$postgres_pid" 2>/dev/null || true
  wait "$postgres_pid" 2>/dev/null || true
}
trap cleanup 0
trap 'exit 1' 1 2 15

until pg_isready --host 127.0.0.1 --port "$port" --username dev --dbname dev >/dev/null 2>&1; do
  kill -0 "$postgres_pid" 2>/dev/null || {
    printf '%s\n' 'PostgreSQL failed to start.' >&2
    exit 1
  }
  sleep 1
done

cd backend
cargo sqlx migrate run --database-url "$database_url"
cargo sqlx prepare --database-url "$database_url"
