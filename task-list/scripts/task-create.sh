#!/usr/bin/env bash
# task-create.sh — create a new task
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

title=""
notes=""
due_at=""
category=""
priority="normal"

while [ $# -gt 0 ]; do
    case "$1" in
        --title)    title="$2";    shift 2 ;;
        --notes)    notes="$2";    shift 2 ;;
        --due-at)   due_at="$2";   shift 2 ;;
        --category) category="$2"; shift 2 ;;
        --priority) priority="$2"; shift 2 ;;
        *) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    esac
done

# Validate title: must be non-blank after trimming
trimmed_title="$(printf '%s' "$title" | tr -d '[:space:]')"
if [ -z "$trimmed_title" ]; then
    echo "ERROR: title is required and must not be blank" >&2
    exit 1
fi

# Validate priority allowlist
validate_priority "$priority"

# Validate due_at format if provided (YYYY-MM-DDTHH:MM:SSZ)
if [ -n "$due_at" ]; then
    if ! printf '%s' "$due_at" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
        echo "ERROR: invalid due_at: must be ISO 8601 UTC datetime (YYYY-MM-DDTHH:MM:SSZ)" >&2
        exit 1
    fi
fi

"${SCRIPT_DIR}/db-init.sh"

# Build optional SQL values
notes_sql="NULL";    [ -n "$notes" ]    && notes_sql="'$(safe_str "$notes")'"
due_at_sql="NULL";   [ -n "$due_at" ]   && due_at_sql="'$(safe_str "$due_at")'"
category_sql="NULL"; [ -n "$category" ] && category_sql="'$(safe_str "$category")'"

result=$(sqlite3 -json "$DB" \
    "INSERT INTO tasks (title, notes, priority, category, due_at)
     VALUES ('$(safe_str "$title")', ${notes_sql}, '$(safe_str "$priority")', ${category_sql}, ${due_at_sql});
     SELECT * FROM tasks WHERE id = last_insert_rowid();" | tr -d '\n')

result="${result#[}"
result="${result%]}"
printf '%s\n' "$result"
