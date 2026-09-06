#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
"${LUA:-lua}" test/client.lua
