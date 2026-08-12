#!/bin/sh
set -eu

cd "$(dirname "$0")"

./build.sh

if process-compose process get backend >/dev/null 2>&1; then
  process-compose process restart backend
else
  # Dynamic ports allow concurrent checkouts and git worktrees.
  process-compose up --detached
fi

printf '%s\n' 'Waiting for the backend to listen...'
until process-compose process ports backend 2>/dev/null | grep -Eq 'ports: \[[0-9]'; do
  sleep 1
done

process-compose process ports backend
process-compose process ports postgres
printf '%s\n' 'Stop with: process-compose down'
