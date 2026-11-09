#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[ -x "$HOME/.cargo/bin/cargo" ] || curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
export PATH="$HOME/.cargo/bin:$PATH"
cargo build --release --locked
cp target/release/notes ./server
{ rustc --version; grep -A1 -E '^name = "(axum|sqlx|tokio|hyper)"$' Cargo.lock | grep -v '^--$' | paste - -; } > versions.txt
rm -rf target
