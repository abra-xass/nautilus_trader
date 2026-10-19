#!/usr/bin/env bash
# Runs focused Sirius checks by default and saves a log.

set -uo pipefail

repo_root="$(git rev-parse --show-toplevel)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="${SIRIUS_TEST_LOG:-${TMPDIR:-/tmp}/sirius-tests-${timestamp}.log}"

if ! mkdir -p "$(dirname "$log_file")"; then
    printf 'Cannot create log directory for %s\n' "$log_file" >&2
    exit 2
fi

exec > >(tee "$log_file") 2>&1

failures=0

run_step() {
    local label="$1"
    shift

    printf '\n===== %s =====\n' "$label"

    if "$@"; then
        printf 'PASS: %s\n' "$label"
    else
        local status=$?
        printf 'FAIL (%s): %s\n' "$status" "$label"
        failures=$((failures + 1))
    fi
}

printf 'Sirius test run started: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'Branch: %s\n' "$(git -C "$repo_root" branch --show-current)"
printf 'Commit: %s\n' "$(git -C "$repo_root" rev-parse --short HEAD)"
printf 'Log file: %s\n' "$log_file"

if [ "${SIRIUS_FULL_TESTS:-0}" = "1" ]; then
    run_step 'NautilusTrader full Rust workspace tests' \
        make -C "$repo_root" cargo-test
    run_step 'NautilusTrader full Python tests' \
        make -C "$repo_root" pytest
else
    run_step 'Sirius core risk tests' \
        env CARGO_INCREMENTAL=0 cargo nextest run --locked \
        -p nautilus-risk --lib --tests --features python --cargo-profile nextest
fi

ui_root="$repo_root/sirius-ui"
if [ -d "$ui_root/backend/tests" ]; then
    run_step 'Sirius UI backend tests' \
        bash -c 'cd "$1" && python -m pytest tests' _ "$ui_root/backend"
else
    printf '\nSKIP: Sirius UI backend tests (sirius-ui/backend/tests not found)\n'
fi

if [ -f "$ui_root/frontend/package.json" ]; then
    run_step 'Sirius UI frontend type check' \
        npm --prefix "$ui_root/frontend" run check
    run_step 'Sirius UI frontend build' \
        npm --prefix "$ui_root/frontend" run build
else
    printf '\nSKIP: Sirius UI frontend checks (sirius-ui/frontend/package.json not found)\n'
fi

printf '\nSirius test run finished with %s failed step(s).\n' "$failures"
printf 'Full log: %s\n' "$log_file"

if [ "$failures" -gt 0 ]; then
    exit 1
fi
