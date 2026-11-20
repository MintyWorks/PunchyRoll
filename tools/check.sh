#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
luau-analyze --definitions=types/roblox_stub.d.luau src tests/unit tests/harness.luau tests/run.luau
