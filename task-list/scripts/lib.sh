#!/usr/bin/env bash
# lib.sh — shared constants and helpers for task-list scripts
# Source this file; do not execute directly.

DB="${HOME}/.openclaw/skills/task-list/tasks.db"

# safe_str VAR — escape single quotes by doubling for SQL string literals
safe_str() {
    printf '%s' "${1//\'/\'\'}"
}

# safe_int VAR — cast to integer; exits 1 if not numeric
safe_int() {
    local val
    val=$(printf '%d' "$1" 2>/dev/null) || { echo "Error: expected integer, got: $1" >&2; exit 1; }
    printf '%d' "$val"
}

# validate_status STATUS — exits 1 if not in allowlist
validate_status() {
    case "$1" in
        new|in-progress|blocked|done|cancelled) ;;
        *) echo "Error: invalid status '$1'. Must be one of: new, in-progress, blocked, done, cancelled" >&2; exit 1 ;;
    esac
}

# validate_priority PRIORITY — exits 1 if not in allowlist
validate_priority() {
    case "$1" in
        low|normal|high) ;;
        *) echo "Error: invalid priority '$1'. Must be one of: low, normal, high" >&2; exit 1 ;;
    esac
}
