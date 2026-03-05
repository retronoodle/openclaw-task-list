# Command Contracts: task-list Skill

**Phase 1 output for**: `001-task-list-skill`
**Date**: 2026-03-05

These contracts define the interface between the OpenClaw agent and the skill's shell
scripts. Each script is invoked by the agent via the `Bash` tool as described in
`SKILL.md`. All scripts output JSON to stdout and errors to stderr with a non-zero exit.

---

## Conventions

- **DB path**: resolved internally; callers do not supply it.
- **Timestamps**: all in ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`).
- **Booleans in JSON**: `true` / `false` (sqlite3 -json uses 1/0 — scripts normalize).
- **Exit codes**: `0` = success, `1` = validation error, `2` = DB error.
- **Null fields**: omitted from JSON objects (not returned as `null`).

---

## 1. `db-init.sh`

Called automatically by every other script before touching the DB.

```
Usage: db-init.sh
Output: (none on success)
Exit:   0 on success, 2 if DB cannot be created/opened
```

---

## 2. `task-create.sh`

Create a new task.

```
Usage: task-create.sh --title TITLE [--notes NOTES] [--due-at ISO8601]
                      [--category CATEGORY] [--priority low|normal|high]

Output (JSON object):
{
  "id": 42,
  "title": "Buy groceries",
  "notes": "Milk, eggs, bread",
  "status": "new",
  "priority": "normal",
  "category": "errands",
  "due_at": "2026-03-06T09:00:00Z",
  "created_at": "2026-03-05T14:22:00Z",
  "updated_at": "2026-03-05T14:22:00Z"
}

Errors (stderr + exit 1):
  "error": "title is required and must not be blank"
  "error": "invalid priority: must be low, normal, or high"
  "error": "invalid due_at: must be ISO 8601 UTC datetime"
```

---

## 3. `task-get.sh`

Retrieve a single task by ID.

```
Usage: task-get.sh --id ID

Output: single task JSON object (same schema as task-create.sh output)

Errors:
  "error": "task not found: 42"
  "error": "id must be a positive integer"
```

---

## 4. `task-update.sh`

Update one or more fields on an existing task. Only supplied flags are changed.

```
Usage: task-update.sh --id ID [--title TITLE] [--notes NOTES] [--due-at ISO8601]
                      [--category CATEGORY] [--priority low|normal|high]
                      [--status new|in-progress|blocked|done|cancelled]
                      [--clear-due-at] [--clear-category] [--clear-notes]

Flags:
  --clear-due-at     set due_at to NULL
  --clear-category   set category to NULL
  --clear-notes      set notes to NULL

Behaviour:
  - updated_at is always set to current UTC on any successful update
  - If --status done: completed_at is set to current UTC
  - If --status is anything other than done: completed_at is set to NULL

Output: updated task JSON object (same schema as task-create.sh)

Errors:
  "error": "task not found: 42"
  "error": "at least one field to update must be specified"
  "error": "invalid status: must be one of new, in-progress, blocked, done, cancelled"
```

---

## 5. `task-delete.sh`

Permanently delete a task by ID.

```
Usage: task-delete.sh --id ID

Output (JSON):
{ "deleted": true, "id": 42 }

Errors:
  "error": "task not found: 42"
  "error": "id must be a positive integer"
```

---

## 6. `task-list.sh`

Query tasks with optional filters. Returns an array (possibly empty).

```
Usage: task-list.sh [--status STATUS] [--category CATEGORY]
                    [--due-before ISO8601] [--due-after ISO8601]
                    [--keyword TEXT] [--show-completed]
                    [--limit N] [--offset N]

Defaults:
  - Excludes done and cancelled tasks unless --show-completed is supplied
  - Ordered by: due_at ASC (nulls last), then created_at ASC
  - No limit unless --limit is supplied

Output (JSON array):
[
  {
    "id": 1,
    "title": "Buy groceries",
    "status": "new",
    "priority": "normal",
    "category": "errands",
    "due_at": "2026-03-06T09:00:00Z",
    "created_at": "2026-03-05T14:22:00Z",
    "updated_at": "2026-03-05T14:22:00Z"
  },
  ...
]

Errors:
  "error": "invalid status filter: ..."
  "error": "database not found — run db-init.sh first"
```

---

## 7. `task-due-soon.sh`

Standalone cron hook. Returns tasks that are overdue or due within the look-ahead window,
excluding done and cancelled. Designed to be invoked from a system crontab.

```
Usage: task-due-soon.sh [--hours N]

Defaults:
  --hours 24   (configurable look-ahead window)

Output (JSON object):
{
  "checked_at": "2026-03-05T14:00:00Z",
  "window_hours": 24,
  "count": 2,
  "tasks": [
    {
      "id": 7,
      "title": "Submit report",
      "status": "in-progress",
      "priority": "high",
      "due_at": "2026-03-05T17:00:00Z",
      "overdue": false
    },
    {
      "id": 3,
      "title": "Pay rent",
      "status": "new",
      "priority": "high",
      "due_at": "2026-03-04T00:00:00Z",
      "overdue": true
    }
  ]
}

Empty result (no tasks due):
{
  "checked_at": "2026-03-05T14:00:00Z",
  "window_hours": 24,
  "count": 0,
  "tasks": []
}

Exit: always 0 (caller decides whether empty = no-op or alert)
```

**Crontab example** (user configures; documented in quickstart.md):
```
0 * * * *  ~/.openclaw/skills/task-list/scripts/task-due-soon.sh --hours 24 >> /tmp/task-alerts.json
```

---

## 8. `categories.sh`

List all distinct category values currently in use.

```
Usage: categories.sh

Output (JSON array of strings):
["errands", "work", "personal"]

Empty: []
```

---

## Error Envelope (all scripts)

On any error, scripts write to **stderr** and exit non-zero:

```
ERROR: <human-readable message>
```

The agent should surface this message to the user as-is.
