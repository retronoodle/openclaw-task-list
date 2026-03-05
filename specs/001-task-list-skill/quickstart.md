# Quickstart: task-list Skill

**Phase 1 output for**: `001-task-list-skill`
**Date**: 2026-03-05

---

## Installation

1. Copy the `task-list/` directory into your OpenClaw skills folder:

   ```bash
   cp -r task-list/ ~/.openclaw/skills/task-list/
   ```

2. Make scripts executable:

   ```bash
   chmod +x ~/.openclaw/skills/task-list/scripts/*.sh
   ```

3. Confirm `sqlite3` is on PATH:

   ```bash
   sqlite3 --version
   # e.g., 3.43.2 2023-10-10 ...
   ```

4. Restart or reload OpenClaw. The skill activates automatically when `sqlite3` is found.

The database is created automatically on first use at:
`~/.openclaw/skills/task-list/tasks.db`

---

## Basic Usage (via agent)

Once the skill is active, talk to the agent naturally:

**Create a task**
> "Add a task: submit the Q1 report by March 10th, high priority, category work"

**List tasks**
> "What's on my task list?"
> "Show me all blocked tasks"
> "What's due this week?"

**Update a task**
> "Mark task 7 as done"
> "Set task 3 priority to high"
> "Move task 12 to in-progress"

**Delete a task**
> "Delete task 5"

**Categories**
> "What categories do I have?"

---

## Cron Hook (Due Date Alerts)

The `task-due-soon.sh` script can be called from a system crontab to get proactive
alerts. It outputs structured JSON so the invoking process or agent can compose
a notification.

### Example crontab entries

Check every hour and print alerts to a log:
```
0 * * * *  ~/.openclaw/skills/task-list/scripts/task-due-soon.sh --hours 24 >> /tmp/task-due-soon.log
```

Check at 8am daily and pipe to an OpenClaw agent message (adjust path as needed):
```
0 8 * * *  ~/.openclaw/skills/task-list/scripts/task-due-soon.sh --hours 24
```

Edit crontab:
```bash
crontab -e
```

### Script output format

```json
{
  "checked_at": "2026-03-05T08:00:00Z",
  "window_hours": 24,
  "count": 1,
  "tasks": [
    {
      "id": 7,
      "title": "Submit report",
      "status": "in-progress",
      "priority": "high",
      "due_at": "2026-03-05T17:00:00Z",
      "overdue": false
    }
  ]
}
```

If `count` is 0 the `tasks` array is empty — no alert needed.

---

## Running Tests

```bash
cd ~/.openclaw/skills/task-list
bash tests/test-create-update-delete.sh
bash tests/test-query-filter.sh
bash tests/test-due-soon.sh
```

Each test creates an isolated temp DB and cleans up on exit.

---

## Uninstall

```bash
rm -rf ~/.openclaw/skills/task-list/
```

This removes the skill, scripts, and the database. No other files are created outside
this directory.
