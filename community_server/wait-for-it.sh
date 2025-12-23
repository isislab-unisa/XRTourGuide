#!/usr/bin/env bash

CS_DB_HOST="$1"
CS_DB_PORT="$2"

if [ -z "$CS_DB_PORT" ]; then
  echo "Usage: $0 host CS_DB_PORT command..."
  exit 1
fi

echo "Waiting for $CS_DB_HOST:$CS_DB_PORT..."

while ! nc -z "$CS_DB_HOST" "$CS_DB_PORT"; do
    sleep 1
done

echo "$CS_DB_HOST:$CS_DB_PORT is available!"
exec "${@:3}"