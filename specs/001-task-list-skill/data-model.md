# Data Model: OpenClaw Task List Skill

**Phase 1 output for**: `001-task-list-skill`
**Date**: 2026-03-05

---

## Schema

Single table. No foreign keys. No secondary tables (Principle V — YAGNI).

```sql
CREATE TABLE IF NOT EXISTS tasks (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    title        TEXT    NOT NULL CHECK(length(trim(title)) > 0),
    notes        TEXT,
    status       TEXT    NOT NULL DEFAULT 'new'
                         CHECK(status IN ('new', 'in-progress', 'blocked', 'done', 'cancelled')),
    priority     TEXT    NOT NULL DEFAULT 'normal'
                         CHECK(priority IN ('low', 'normal', 'high')),
    category     TEXT,
    due_at       TEXT,           -- ISO 8601 UTC: "YYYY-MM-DDTHH:MM:SSZ", nullable
    created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    completed_at TEXT            -- set to current UTC when status transitions to 'done', else NULL
);
```

---

## Indexes

```sql
-- Due-soon queries filter on due_at + status
CREATE INDEX IF NOT EXISTS idx_tasks_due_at   ON tasks (due_at)   WHERE due_at IS NOT NULL;

-- Status filter (list, due-soon exclusions)
CREATE INDEX IF NOT EXISTS idx_tasks_status   ON tasks (status);

-- Category filter
CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks (category) WHERE category IS NOT NULL;
```

---

## Fields

| Field | Type | Nullable | Default | Notes |
|-------|------|----------|---------|-------|
| `id` | INTEGER | No | auto | Auto-assigned; never supplied by caller |
| `title` | TEXT | No | — | Required; must not be blank after trim |
| `notes` | TEXT | Yes | NULL | Free-form text |
| `status` | TEXT | No | `'new'` | Enum: `new`, `in-progress`, `blocked`, `done`, `cancelled` |
| `priority` | TEXT | No | `'normal'` | Enum: `low`, `normal`, `high` |
| `category` | TEXT | Yes | NULL | Free-text label; no managed category table |
| `due_at` | TEXT | Yes | NULL | ISO 8601 UTC string; compared lexicographically (valid because format is fixed) |
| `created_at` | TEXT | No | `now()` UTC | Set at insert; never updated |
| `updated_at` | TEXT | No | `now()` UTC | Updated on every UPDATE |
| `completed_at` | TEXT | Yes | NULL | Set when `status` transitions to `'done'`; cleared if status moves away from `'done'` |

---

## Validation Rules

- `title`: must be non-empty after `trim()`. Enforced at script boundary (shell) before SQL.
- `status`: must be one of the five allowed values. Enforced via shell allowlist check + SQL CHECK constraint.
- `priority`: must be one of three allowed values. Same enforcement.
- `due_at`: must be a valid ISO 8601 UTC datetime if provided. Validated in shell via `date` parsing before insert.
- `id` on update/delete: must be a positive integer. Enforced via `printf '%d'` cast.

---

## State Transitions

```
         ┌─────────────────────────────────┐
         │                                 ▼
       new ──► in-progress ──► done     cancelled
         │         │            ▲
         │         └────────────┘
         │
         └──► blocked ──► in-progress
                  │
                  └──► done
```

- Any status may transition to `cancelled`.
- `completed_at` is set when entering `done`; cleared when leaving `done`.
- No enforcement of valid transitions in DB (agent handles workflow logic).

---

## Default Query Ordering

When no explicit ORDER BY is requested:

```sql
ORDER BY
    CASE WHEN due_at IS NULL THEN 1 ELSE 0 END,  -- nulls last
    due_at ASC,
    created_at ASC
```

---

## DB Path

`~/.openclaw/skills/task-list/tasks.db`

Resolved in scripts as: `DB="${HOME}/.openclaw/skills/task-list/tasks.db"`

Directory is created by `db-init.sh` if absent.
