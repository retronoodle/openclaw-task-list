#!/usr/bin/env bash
# categories.sh — list distinct category values
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

"${SCRIPT_DIR}/db-init.sh"

# Build a JSON array of strings using SQLite's group_concat
result=$(sqlite3 "${DB}" \
    "SELECT '[' || COALESCE(group_concat('\"' || replace(category, '\"', '\\\"') || '\"', ','), '') || ']'
     FROM (SELECT DISTINCT category FROM tasks WHERE category IS NOT NULL ORDER BY category);")

printf '%s\n' "$result"
