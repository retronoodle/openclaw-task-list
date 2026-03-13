#!/usr/bin/env bash
# task-delete.sh — permanently delete a task by ID
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

check=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE id = ${safe_id};")
if [ "$check" -eq 0 ]; then
    echo "ERROR: task not found: ${safe_id}" >&2
    exit 1
fi

sqlite3 "$DB" "DELETE FROM tasks WHERE id = ${safe_id};"
printf '{"deleted":true,"id":%d}\n' "$safe_id"
