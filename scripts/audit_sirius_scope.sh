#!/usr/bin/env bash
# Inventories branding and product-model references for the Sirius migration.

set -uo pipefail

repo_root="$(git rev-parse --show-toplevel)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="${SIRIUS_AUDIT_LOG:-${TMPDIR:-/tmp}/sirius-scope-${timestamp}.log}"

if ! mkdir -p "$(dirname "$log_file")"; then
    printf 'Cannot create log directory for %s\n' "$log_file" >&2
    exit 2
fi

cd "$repo_root"
exec > >(tee "$log_file") 2>&1

audit_group() {
    local label="$1"
    local pattern="$2"
    local pathspecs=(. ':(exclude)scripts/audit_sirius_scope.sh' ':(exclude)RELEASES.md')
    local files
    local file_count
    local line_count

    files="$(git grep -I -l -E "$pattern" -- "${pathspecs[@]}" || true)"
    file_count="$(printf '%s\n' "$files" | sed '/^$/d' | wc -l | tr -d ' ')"
    line_count="$(git grep -I -E "$pattern" -- "${pathspecs[@]}" | wc -l | tr -d ' ')"

    printf '\n===== %s =====\n' "$label"
    printf 'Matching files: %s\n' "$file_count"
    printf 'Matching lines: %s\n' "$line_count"
    if [ -n "$files" ]; then
        printf '%s\n' "$files"
    fi
}

printf 'Sirius source inventory started: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'Branch: %s\n' "$(git branch --show-current)"
printf 'Commit: %s\n' "$(git rev-parse --short HEAD)"
printf 'Release history is excluded from rename counts by project policy.\n'

audit_group 'Nautilus product and package branding' \
    'NautilusTrader|Nautilus Trader|nautilus_trader|nautilus-trader'
audit_group 'Futures and perpetual product references' \
    'CryptoFuture|CryptoPerpetual|FuturesContract|PerpetualContract|FuturesSpread|InstrumentClass::Future|InstrumentClass::Swap|FUTURES|PERPETUAL'
audit_group 'Short-position behavior' \
    'PositionSide::Short|PositionSide\.Short|is_short|short_qty|open.?short|short.?position|SHORT'

printf '\nFull inventory log: %s\n' "$log_file"
