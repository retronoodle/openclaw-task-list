#!/usr/bin/env bash
# task-get.sh — retrieve a single task by ID
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

id=""

while [ $# -gt 0 ]; do
    case "$1" in
        --id) id="$2"; shift 2 ;;
        *) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$id" ]; then
    echo "ERROR: --id is required" >&2
    exit 1
fi

safe_id=$(safe_int "$id")
if [ "$safe_id" -le 0 ]; then
    echo "ERROR: id must be a positive integer" >&2
    exit 1
fi

"${SCRIPT_DIR}/db-init.sh"

result=$(sqlite3 -json "$DB" "SELECT * FROM tasks WHERE id = ${safe_id};" | tr -d '\n')

if [ -z "$result" ] || [ "$result" = "[]" ]; then
    echo "ERROR: task not found: ${safe_id}" >&2
    exit 1
fi

result="${result#[}"
result="${result%]}"
printf '%s\n' "$result"
