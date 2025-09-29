#!/usr/bin/env bash

HOST="$1"
PORT="$2"

if [ -z "$PORT" ]; then
  echo "Usage: $0 host port command..."
  exit 1
fi

echo "Waiting for $HOST:$PORT..."

while ! nc -z "$HOST" "$PORT"; do
    sleep 1
done

echo "$HOST:$PORT is available!"
exec "${@:3}"