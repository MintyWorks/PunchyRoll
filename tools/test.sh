#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

prelude="$(mktemp)"
trap 'rm -f "$prelude"' EXIT
for file in tests/mock/*.luau; do
	printf 'do\n' >> "$prelude"
	cat "$file" >> "$prelude"
	printf '\nend\n' >> "$prelude"
done

if [ "$#" -gt 0 ]; then
	LUAU_PRELUDE="$prelude" luau tests/run.luau -a "$@"
else
	LUAU_PRELUDE="$prelude" luau tests/run.luau
fi
