# Implementation Plan: OpenClaw Task List Skill

**Branch**: `001-task-list-skill` | **Date**: 2026-03-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-task-list-skill/spec.md`

## Summary

Implement a self-contained OpenClaw skill that manages tasks in a local SQLite database.
The skill exposes shell scripts for CRUD operations, filtering, and a standalone due-soon
cron hook. All data is stored in `~/.openclaw/skills/task-list/tasks.db` with no external
dependencies beyond the `sqlite3` binary.

## Technical Context

**Language/Version**: Bash (POSIX-compatible), sqlite3 CLI (any version ≥ 3.37)
**Primary Dependencies**: sqlite3 (declared in requires.bins)
**Storage**: SQLite — single file at `~/.openclaw/skills/task-list/tasks.db`
**Testing**: Bash test scripts with isolated temp DBs (no external framework)
**Target Platform**: macOS (darwin) + Linux
**Project Type**: OpenClaw Skill (AgentSkills spec)
**Performance Goals**: Due-soon query < 2s on 10,000-task DB (indexed; trivially met)
**Constraints**: Offline-capable, no network calls, no config required, drop-in install
**Scale/Scope**: Single user, up to ~10k tasks

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. OpenClaw Skill Compatibility | ✅ PASS | SKILL.md with valid frontmatter; name matches directory; AgentSkills spec followed |
| II. Self-Contained SQLite Storage | ✅ PASS | Single `tasks.db` at declared deterministic path; `sqlite3` in `requires.bins`; no external services |
| III. Security — No Injection | ✅ PASS | Integer IDs via `printf '%d'`; text via single-quote doubling; enums via allowlist; see research.md §2 |
| IV. Portability & Eligibility | ✅ PASS | `os: ["darwin","linux"]`; `requires.bins: ["sqlite3"]`; no host config beyond OpenClaw + sqlite3 |
| V. Simplicity (YAGNI) | ✅ PASS | Single `tasks` table; minimal script set; no abstractions for hypothetical future needs |

**Post-Phase 1 re-check**: All principles confirmed after design. Single `tasks` table
(no joins, no secondary tables). No complexity violations to log.

## Project Structure

### Documentation (this feature)

```text
specs/001-task-list-skill/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── commands.md
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
task-list/
├── SKILL.md                      # Skill entry point (frontmatter + agent instructions)
├── scripts/
│   ├── db-init.sh                # Create DB and tables if not exist (called by all other scripts)
│   ├── task-create.sh            # Create a new task
│   ├── task-get.sh               # Get a single task by ID
│   ├── task-update.sh            # Update fields on an existing task
│   ├── task-delete.sh            # Delete a task by ID
│   ├── task-list.sh              # Query/filter tasks (status, category, keyword, date range)
│   ├── task-due-soon.sh          # Standalone cron hook — due/overdue tasks as JSON
│   └── categories.sh             # List distinct category values
└── tests/
    ├── test-create-update-delete.sh
    ├── test-query-filter.sh
    └── test-due-soon.sh
```

**Structure Decision**: Single-project layout. The skill lives in a `task-list/` directory
at the repo root (matching the OpenClaw skill name). All logic is pure shell scripts under
`scripts/`. Tests are co-located under `tests/` within the skill directory.

## Complexity Tracking

*No constitution violations — table not required.*
