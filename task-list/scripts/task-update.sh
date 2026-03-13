#!/usr/bin/env bash
# task-update.sh — update one or more fields on an existing task
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

id=""
title=""
notes=""
due_at=""
category=""
priority=""
status=""
clear_due_at=0
clear_category=0
clear_notes=0

while [ $# -gt 0 ]; do
    case "$1" in
        --id)             id="$2";       shift 2 ;;
        --title)          title="$2";    shift 2 ;;
        --notes)          notes="$2";    shift 2 ;;
        --due-at)         due_at="$2";   shift 2 ;;
        --category)       category="$2"; shift 2 ;;
        --priority)       priority="$2"; shift 2 ;;
        --status)         status="$2";   shift 2 ;;
        --clear-due-at)   clear_due_at=1;   shift ;;
        --clear-category) clear_category=1; shift ;;
        --clear-notes)    clear_notes=1;    shift ;;
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

# Build SET clause incrementally
set_clauses=""
has_fields=0

add_clause() {
    if [ -n "$set_clauses" ]; then
        set_clauses="${set_clauses}, $1"
    else
        set_clauses="$1"
    fi
    has_fields=1
}

# Title: validate non-blank if provided
if [ -n "$title" ]; then
    trimmed="$(printf '%s' "$title" | tr -d '[:space:]')"
    if [ -z "$trimmed" ]; then
        echo "ERROR: title must not be blank" >&2
        exit 1
    fi
    add_clause "title = '$(safe_str "$title")'"
fi

[ -n "$notes" ]    && add_clause "notes = '$(safe_str "$notes")'"
[ -n "$due_at" ]   && add_clause "due_at = '$(safe_str "$due_at")'"
[ -n "$category" ] && add_clause "category = '$(safe_str "$category")'"

if [ -n "$priority" ]; then
    validate_priority "$priority"
    add_clause "priority = '$(safe_str "$priority")'"
fi

if [ -n "$status" ]; then
    validate_status "$status"
    add_clause "status = '$(safe_str "$status")'"
fi

[ "$clear_due_at" -eq 1 ]   && add_clause "due_at = NULL"
[ "$clear_category" -eq 1 ] && add_clause "category = NULL"
[ "$clear_notes" -eq 1 ]    && add_clause "notes = NULL"

if [ "$has_fields" -eq 0 ]; then
    echo "ERROR: at least one field to update must be specified" >&2
    exit 1
fi

# Handle completed_at based on status transition
if [ -n "$status" ]; then
    if [ "$status" = "done" ]; then
        add_clause "completed_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')"
    else
        add_clause "completed_at = NULL"
    fi
fi

# updated_at always refreshed
add_clause "updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')"

"${SCRIPT_DIR}/db-init.sh"

# Verify task exists
check=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE id = ${safe_id};")
if [ "$check" -eq 0 ]; then
    echo "ERROR: task not found: ${safe_id}" >&2
    exit 1
fi

sqlite3 "$DB" "UPDATE tasks SET ${set_clauses} WHERE id = ${safe_id};"

result=$(sqlite3 -json "$DB" "SELECT * FROM tasks WHERE id = ${safe_id};" | tr -d '\n')
result="${result#[}"
result="${result%]}"
printf '%s\n' "$result"
