#!/usr/bin/env bash
# task-list.sh — query/filter tasks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

status_filter=""
category=""
due_before=""
due_after=""
keyword=""
show_completed=0
limit=""
offset=""

while [ $# -gt 0 ]; do
    case "$1" in
        --status)         status_filter="$2"; shift 2 ;;
        --category)       category="$2";      shift 2 ;;
        --due-before)     due_before="$2";    shift 2 ;;
        --due-after)      due_after="$2";     shift 2 ;;
        --keyword)        keyword="$2";       shift 2 ;;
        --show-completed) show_completed=1;   shift ;;
        --limit)          limit="$2";         shift 2 ;;
        --offset)         offset="$2";        shift 2 ;;
        *) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    esac
done

# Validate status filter if provided
if [ -n "$status_filter" ]; then
    validate_status "$status_filter"
fi

# Validate limit/offset as integers if provided
if [ -n "$limit" ]; then
    limit=$(safe_int "$limit")
fi
if [ -n "$offset" ]; then
    offset=$(safe_int "$offset")
fi

"${SCRIPT_DIR}/db-init.sh"

# Build WHERE clause
where=""

add_cond() {
    if [ -z "$where" ]; then
        where="$1"
    else
        where="${where} AND $1"
    fi
}

if [ -n "$status_filter" ]; then
    add_cond "status = '$(safe_str "$status_filter")'"
elif [ "$show_completed" -eq 0 ]; then
    add_cond "status NOT IN ('done', 'cancelled')"
fi

if [ -n "$category" ]; then
    add_cond "category = '$(safe_str "$category")'"
fi

if [ -n "$due_before" ]; then
    add_cond "due_at <= '$(safe_str "$due_before")'"
fi

if [ -n "$due_after" ]; then
    add_cond "due_at >= '$(safe_str "$due_after")'"
fi

if [ -n "$keyword" ]; then
    kw="$(safe_str "$keyword")"
    add_cond "(title LIKE '%${kw}%' OR notes LIKE '%${kw}%')"
fi

# Build full SQL
sql="SELECT * FROM tasks"
[ -n "$where" ] && sql="${sql} WHERE ${where}"
# NULL-safe ASC: (due_at IS NULL) = 1 for NULLs, 0 otherwise — sort 0 first
sql="${sql} ORDER BY (due_at IS NULL) ASC, due_at ASC, created_at ASC"
[ -n "$limit" ]  && sql="${sql} LIMIT ${limit}"
[ -n "$offset" ] && sql="${sql} OFFSET ${offset}"

result=$(sqlite3 -json "${DB}" "${sql}")

# sqlite3 -json returns NULL when no rows; normalise to empty array
if [ -z "$result" ] || [ "$result" = "null" ]; then
    printf '[]\n'
else
    printf '%s\n' "$result"
fi
