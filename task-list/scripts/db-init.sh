#!/usr/bin/env bash
# db-init.sh — initialise the task-list SQLite database
# Safe to run multiple times (CREATE IF NOT EXISTS).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

mkdir -p "$(dirname "${DB}")"

sqlite3 "${DB}" <<'SQL' || { echo "Error: database initialisation failed" >&2; exit 2; }
CREATE TABLE IF NOT EXISTS tasks (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    title        TEXT    NOT NULL CHECK(length(trim(title)) > 0),
    notes        TEXT,
    status       TEXT    NOT NULL DEFAULT 'new'
                         CHECK(status IN ('new', 'in-progress', 'blocked', 'done', 'cancelled')),
    priority     TEXT    NOT NULL DEFAULT 'normal'
                         CHECK(priority IN ('low', 'normal', 'high')),
    category     TEXT,
    due_at       TEXT,
    created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_tasks_due_at   ON tasks (due_at)   WHERE due_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_status   ON tasks (status);
CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks (category) WHERE category IS NOT NULL;
SQL
