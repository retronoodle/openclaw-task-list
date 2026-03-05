# Research: OpenClaw Task List Skill

**Phase 0 output for**: `001-task-list-skill`
**Date**: 2026-03-05

---

## 1. OpenClaw SKILL.md Format

**Decision**: Use the AgentSkills spec frontmatter with OpenClaw extensions.

**Rationale**: OpenClaw follows the AgentSkills open standard. The SKILL.md frontmatter
is parsed as YAML with single-line keys only (OpenClaw parser constraint). Tool interfaces
are described in the markdown body (natural language + code blocks) — there is no
structured YAML schema for tool inputs/outputs.

**Key fields for this skill**:
```yaml
---
name: task-list
description: >- (single-line)
user-invocable: true
metadata: {"openclaw":{"emoji":"✅","os":["darwin","linux"],"requires":{"bins":["sqlite3"]}}}
---
```

**Alternatives considered**: JSON-schema tool definitions in frontmatter — not supported
by the OpenClaw parser.

---

## 2. Shell Script Parameterization (SQL Injection Prevention)

**Decision**: Two-tier approach:
1. **Integer IDs**: `printf '%d' "$id"` — guarantees numeric-only interpolation.
2. **Text values**: Escape single quotes by doubling (`${var//\'/''}`), then wrap in
   single-quoted SQL string literals. This is SQLite's own escaping rule and is safe
   for the `sqlite3` CLI.
3. **Enum/status values**: Validate against an allowlist in shell before interpolation
   (e.g., `case "$status" in new|in-progress|blocked|done|cancelled) ;; *) exit 1`).

**Rationale**: The `sqlite3` CLI does not support true parameterized queries in the
same way a driver would. The `.param set` feature exists but requires careful shell
quoting that can itself introduce injection if not handled correctly. The doubling
approach is the established safe pattern for sqlite3 CLI scripts; it is SQL-standard
for string literals and has no edge cases for arbitrary UTF-8 text.

**Alternatives considered**:
- `.param set :name "$value"` — shell still expands `$value` into the command, so a
  value containing `"` or `` ` `` can break the param command. Rejected as more complex
  without being safer in pure-bash context.
- Python/Node wrapper for DB access — adds an undeclared dependency. Rejected (YAGNI).

---

## 3. Cron / Standalone CLI Invocation

**Decision**: The due-soon check is implemented as a standalone executable shell script
(`scripts/task-due-soon.sh`) that can be invoked directly from a system crontab. It
outputs JSON to stdout and exits 0 on success.

**Rationale**: OpenClaw's internal cron system is for scheduling agent turns, not for
running skill-internal logic on a timer. For a task-list skill the cron pattern is:
a system crontab entry calls the standalone script → script queries SQLite → outputs
JSON → the invoking process (or a piped OpenClaw `openclaw cron` job) feeds the result
to the agent for human notification.

**Look-ahead window**: Defaults to 24 hours; overridable via `--hours N` CLI flag.

**Crontab example** (user sets up manually, documented in quickstart.md):
```
0 * * * * /path/to/skills/task-list/scripts/task-due-soon.sh --hours 24 | openclaw message "Task reminder: $(cat)"
```

**Alternatives considered**: Embedding cron schedule in SKILL.md frontmatter —
no such field exists in the AgentSkills spec. Rejected.

---

## 4. Database Path

**Decision**: `~/.openclaw/skills/task-list/tasks.db` (resolved at runtime via
`$HOME/.openclaw/skills/task-list/tasks.db`).

**Rationale**: Keeps the DB alongside the skill data directory, within the user's
OpenClaw workspace. Deterministic — no user config needed. Easily cleaned up by
removing the skill directory.

**Alternatives considered**: `$XDG_DATA_HOME/task-list/tasks.db` — adds XDG logic
complexity. Rejected (YAGNI). Skill directory itself — may conflict with read-only
skill installs. Resolved by using the `~/.openclaw/skills/` runtime directory.

---

## 5. Task ID Strategy

**Decision**: `INTEGER PRIMARY KEY AUTOINCREMENT` (SQLite auto-assigned integer).

**Rationale**: Simple, unique, agent-friendly for update/delete by ID. The agent
does not supply IDs. Spec says "Task IDs are auto-assigned at creation."

---

## 6. Testing Strategy

**Decision**: Minimal bash test scripts using `sqlite3` directly against a temp DB.
No external test framework required.

**Rationale**: The skill is pure shell + sqlite3. bats would add a dependency not
declared in `requires.bins`. Simple assertion scripts (exit 1 on failure) keep tests
self-contained and runnable anywhere sqlite3 is present.

**Test DB**: Each test script creates an isolated temp DB (`mktemp`) and cleans up
on exit via `trap`.

---

## 7. Output Format

**Decision**: All script output is JSON (stdout). Errors go to stderr with a
non-zero exit code.

**Rationale**: The agent needs to parse structured results. JSON is the lingua franca
for tool output. `sqlite3 -json` mode produces JSON arrays natively — no manual
serialization needed.

---

## Summary of Resolved Unknowns

| Unknown | Resolution |
|---------|-----------|
| SKILL.md tool input/output schema | Natural language in body + shell scripts; no YAML schema |
| Parameterized SQL in bash | Single-quote doubling + enum allowlists |
| Cron invocation pattern | Standalone CLI script, system crontab, JSON stdout |
| DB path | `~/.openclaw/skills/task-list/tasks.db` |
| Task IDs | SQLite AUTOINCREMENT integers |
| Testing | Bash scripts + temp SQLite DB, no external framework |
| Output format | JSON via `sqlite3 -json` |
