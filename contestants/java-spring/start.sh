#!/usr/bin/env bash
cd "$(dirname "$0")"; exec java -jar app.jar --server.address="$HOST" --server.port="$PORT"
