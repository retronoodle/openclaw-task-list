# Tasks: OpenClaw Task List Skill

**Input**: Design documents from `/specs/001-task-list-skill/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/commands.md ✅

**Tests**: Included — plan.md defines `tests/` directory and spec.md provides detailed
Independent Test criteria that map directly to automated bash test scenarios. Constitution
quality gate requires tests pass before feature is complete.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this belongs to (US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Directory structure, SKILL.md skeleton, and shared shell helpers.

- [X] T001 Create skill directory tree: `task-list/`, `task-list/scripts/`, `task-list/tests/` per plan.md structure
- [X] T002 Create skeleton `task-list/SKILL.md` with valid frontmatter: `name: task-list`, single-line `description`, `user-invocable: true`, `metadata: {"openclaw":{"emoji":"✅","os":["darwin","linux"],"requires":{"bins":["sqlite3"]}}}`
- [X] T003 Create `task-list/scripts/lib.sh` — export `DB` path constant (`$HOME/.openclaw/skills/task-list/tasks.db`), `safe_str()` helper (single-quote doubling), `safe_int()` helper (`printf '%d'`), status/priority allowlist validators

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Database initialisation — MUST be complete before any user story script can be built or tested.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 Create `task-list/scripts/db-init.sh` — source `lib.sh`, mkdir DB parent dir, run `CREATE TABLE IF NOT EXISTS tasks (...)` per data-model.md schema with all CHECK constraints, create three indexes (due_at, status, category), exit 2 on DB error

**Checkpoint**: DB schema ready — user story implementation can now begin.

---

## Phase 3: User Story 1 — Create and Manage Tasks (Priority: P1) 🎯 MVP

**Goal**: Full CRUD for tasks; agent can create, read, update, and delete tasks in one turn.

**Independent Test**: Create a task with title only → verify it appears with status "new" → update status to "done" → verify `completed_at` is set → delete it → verify it no longer appears.

### Tests for User Story 1

> **Write tests FIRST — verify they FAIL before implementing T006–T009**

- [ ] T005 [P] [US1] Create `task-list/tests/test-create-update-delete.sh` — temp DB via `mktemp`, `trap` cleanup, assert helpers (assert_eq, assert_json_field), test cases: (a) create with title only returns id+status=new, (b) blank title is rejected exit 1, (c) update status to done sets completed_at, (d) update status away from done clears completed_at, (e) delete returns deleted:true, (f) get after delete returns error

### Implementation for User Story 1

- [ ] T006 [P] [US1] Implement `task-list/scripts/task-create.sh` — parse flags (--title, --notes, --due-at, --category, --priority), call `db-init.sh`, validate title non-blank and priority allowlist and due_at format, INSERT with `safe_str()`/`safe_int()`, return task JSON via `sqlite3 -json`
- [ ] T007 [P] [US1] Implement `task-list/scripts/task-get.sh` — parse --id, call `db-init.sh`, `safe_int()` cast, SELECT by id, exit 1 with error if not found, return task JSON via `sqlite3 -json`
- [ ] T008 [US1] Implement `task-list/scripts/task-update.sh` — parse all update flags (--title, --notes, --due-at, --category, --priority, --status, --clear-due-at, --clear-category, --clear-notes), require at least one field, build SET clause safely, set `updated_at` always, set/clear `completed_at` on status transition, return updated task JSON (depends on T006 patterns established)
- [ ] T009 [US1] Implement `task-list/scripts/task-delete.sh` — parse --id, `safe_int()` cast, verify task exists, DELETE, return `{"deleted":true,"id":N}` JSON

**Checkpoint**: User Story 1 fully functional — run `test-create-update-delete.sh` independently.

---

## Phase 4: User Story 2 — Query and Filter Tasks (Priority: P2)

**Goal**: Agent can list all tasks or filter by status, category, keyword, and date range; can list categories.

**Independent Test**: Create three tasks with different statuses and categories → query by status "new" → verify only matching tasks returned → query by category → verify correct subset → keyword search → verify title/notes match.

### Tests for User Story 2

> **Write tests FIRST — verify they FAIL before implementing T011–T012**

- [ ] T010 [P] [US2] Create `task-list/tests/test-query-filter.sh` — temp DB, seed 5 tasks (varied status/category/notes/due_at), test cases: (a) no-filter excludes done/cancelled, (b) --status filter, (c) --category filter, (d) --due-before filter, (e) --keyword matches title and notes, (f) --show-completed includes done tasks, (g) default ordering (due_at nulls last then created_at)

### Implementation for User Story 2

- [ ] T011 [P] [US2] Implement `task-list/scripts/task-list.sh` — parse filter flags (--status, --category, --due-before, --due-after, --keyword, --show-completed, --limit, --offset), build WHERE clause with `safe_str()` for text values and status allowlist, default exclude done/cancelled, ORDER BY due_at ASC (nulls last) then created_at ASC, return JSON array via `sqlite3 -json`
- [ ] T012 [P] [US2] Implement `task-list/scripts/categories.sh` — call `db-init.sh`, `SELECT DISTINCT category FROM tasks WHERE category IS NOT NULL ORDER BY category`, return JSON array of strings

**Checkpoint**: User Stories 1 AND 2 independently functional — run `test-query-filter.sh`.

---

## Phase 5: User Story 3 — Due Date Alerts via Cron Hook (Priority: P3)

**Goal**: Standalone CLI script returns overdue/due-soon tasks as structured JSON; invocable from system crontab.

**Independent Test**: Create a task due 30 minutes from now → run `task-due-soon.sh --hours 1` → verify task appears with `overdue: false` → mark done → re-run → verify task no longer appears.

### Tests for User Story 3

> **Write tests FIRST — verify they FAIL before implementing T014**

- [ ] T013 [P] [US3] Create `task-list/tests/test-due-soon.sh` — temp DB, test cases: (a) task due in 1h appears with `overdue:false` when --hours 2, (b) task due 1h ago appears with `overdue:true`, (c) done task does NOT appear, (d) cancelled task does NOT appear, (e) no tasks due → count:0 and tasks:[], (f) default --hours is 24, (g) output includes checked_at and window_hours fields

### Implementation for User Story 3

- [ ] T014 [US3] Implement `task-list/scripts/task-due-soon.sh` — parse optional --hours N (default 24), call `db-init.sh`, compute cutoff as `datetime('now', '+N hours')`, query tasks where `due_at <= cutoff AND due_at IS NOT NULL AND status NOT IN ('done','cancelled')`, compute `overdue` flag per row (`due_at < datetime('now')`), emit JSON envelope `{checked_at, window_hours, count, tasks:[...]}` to stdout, always exit 0

**Checkpoint**: All three user stories independently functional — run all three test scripts.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: SKILL.md agent instructions, executable bits, edge case hardening, install validation.

- [ ] T015 Complete `task-list/SKILL.md` body — write full agent instructions: how to invoke each script for CRUD, filtering, categories, due-soon; include example Bash tool calls; document DB path; note cron setup; reference contracts/commands.md for full flag reference
- [ ] T016 [P] Add shebang (`#!/usr/bin/env bash`) and `set -euo pipefail` to all scripts in `task-list/scripts/`; verify `chmod +x` on all scripts
- [ ] T017 [P] Add edge case guards per spec.md Edge Cases section: (a) `task-create.sh` rejects blank/whitespace-only title with clear error, (b) all scripts surface "database not found" as clear error (not silent empty), (c) past `due_at` accepted at creation with no error
- [ ] T018 Validate against `quickstart.md` install steps — copy `task-list/` to a temp dir, run `db-init.sh`, run all three test suites, confirm clean exit; document any corrections needed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately; T002 and T003 can run in parallel after T001
- **Foundational (Phase 2)**: Requires T003 (lib.sh) — BLOCKS all user stories
- **User Stories (Phases 3–5)**: All require T004 (db-init.sh); user stories can proceed sequentially P1→P2→P3
- **Polish (Phase 6)**: Requires all user story phases complete

### User Story Dependencies

- **US1 (P1)**: Requires Phase 2 only — no story dependencies
- **US2 (P2)**: Requires Phase 2 — independently testable; `task-list.sh` does not depend on US1 scripts
- **US3 (P3)**: Requires Phase 2 — independently testable; `task-due-soon.sh` does not depend on US1/US2 scripts

### Within Each User Story

- Tests written and confirmed FAILING before implementation
- US1: T005 (tests) → T006, T007 in parallel → T008, T009 sequentially
- US2: T010 (tests) → T011, T012 in parallel
- US3: T013 (tests) → T014

### Parallel Opportunities

- T002 + T003 (Phase 1) — different files
- T006 + T007 (US1 implementation) — different scripts, same pattern from lib.sh
- T011 + T012 (US2 implementation) — different scripts
- T016 + T017 (Polish) — different concerns

---

## Parallel Example: User Story 1

```bash
# After T005 tests written and confirmed failing:
Task: "Implement task-list/scripts/task-create.sh"   # T006
Task: "Implement task-list/scripts/task-get.sh"       # T007
# Both can run in parallel — different files, same lib.sh patterns
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004) — CRITICAL
3. Complete Phase 3: User Story 1 (T005–T009)
4. **STOP and VALIDATE**: `bash task-list/tests/test-create-update-delete.sh`
5. Agent can create, read, update, delete tasks — MVP complete

### Incremental Delivery

1. Setup + Foundational → foundation ready
2. US1 → test independently → MVP (agent manages tasks)
3. US2 → test independently → agent can filter/search
4. US3 → test independently → cron alerts working
5. Polish → production-ready skill

---

## Notes

- All scripts must source `lib.sh` for DB path and safe quoting — never hardcode path or duplicate escaping logic
- `sqlite3 -json` handles JSON serialization — no manual JSON construction needed for row data
- Envelope JSON (e.g., due-soon wrapper) constructed via `printf` with integer fields only — safe
- Tests use isolated temp DBs (`mktemp`) — never touch the real `tasks.db`
- Commit after each checkpoint (T009, T012, T014, T018)
