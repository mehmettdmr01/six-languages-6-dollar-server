#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export GOPATH="$HOME/go" GOFLAGS=-mod=mod CGO_ENABLED=1
go mod tidy
go build -o server .
{ go version; grep mattn go.mod; } > versions.txt
