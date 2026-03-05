# Feature Specification: OpenClaw Task List Skill

**Feature Branch**: `001-task-list-skill`
**Created**: 2026-03-05
**Status**: Draft
**Input**: User description: "This is an openclaw skill, it should be a task list that is self contained with a sqlite db. It should support tasks with and without due dates, it should have statuses, 'done', 'new', etc, it should support optional categories as well. Any other things you think it should support can be included. Its made for an autonomous agent, so it should have a cron hook as well, so it can be activated by a cron that would alert the bot (on tasks with due dates) so the bot can alert the human. Also the agent needs to be able to query it at will or when the human asks."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create and Manage Tasks (Priority: P1)

A human user (or agent acting on the human's behalf) needs to create, update, and remove
tasks. Tasks may optionally have a due date and a category. Every task has a status that
reflects its lifecycle: new, in-progress, blocked, done, or cancelled.

**Why this priority**: Core task management is the foundation everything else builds on.
Without it, no other story is possible.

**Independent Test**: Create a task with a title only, verify it appears in the task list
with status "new". Update its status to "done", verify it is marked complete. Delete it,
verify it no longer appears.

**Acceptance Scenarios**:

1. **Given** the skill is active, **When** the agent creates a task with a title and
   optional due date and category, **Then** the task is persisted and returned with a
   unique ID, status "new", and a creation timestamp.
2. **Given** a task exists, **When** the agent updates its status to "done",
   **Then** the task reflects the new status and a completion timestamp is recorded.
3. **Given** a task exists, **When** the agent deletes it, **Then** it no longer appears
   in any query results.
4. **Given** a task exists, **When** the agent updates its title, due date, or category,
   **Then** the task reflects the updated values.

---

### User Story 2 - Query and Filter Tasks (Priority: P2)

The agent (or human via the agent) can retrieve all tasks or a filtered subset — by
status, category, due date range, or free-text search on the title/notes.

**Why this priority**: The human needs to ask "what's on my list?" and "what's due
today?" without receiving irrelevant clutter.

**Independent Test**: Create three tasks with different statuses and categories. Query
by status "new" and verify only matching tasks are returned. Query by category and verify
the correct subset.

**Acceptance Scenarios**:

1. **Given** multiple tasks exist, **When** the agent queries with no filters, **Then**
   all non-done/non-cancelled tasks are returned ordered by due date (nulls last), then
   creation date.
2. **Given** tasks with different statuses exist, **When** the agent filters by status,
   **Then** only tasks matching that status are returned.
3. **Given** tasks with categories exist, **When** the agent filters by category,
   **Then** only tasks in that category are returned.
4. **Given** tasks with due dates exist, **When** the agent queries for tasks due before
   a given date, **Then** only those tasks are returned.
5. **Given** tasks with titles/notes, **When** the agent searches by keyword,
   **Then** tasks whose title or notes contain the keyword are returned.

---

### User Story 3 - Due Date Alerts via Cron Hook (Priority: P3)

An automated cron process invokes the skill to retrieve tasks that are overdue or due
within a configurable look-ahead window. The skill returns a structured list the agent
uses to compose a human-readable alert.

**Why this priority**: Proactive alerting is what makes this useful as an autonomous
agent skill — the human should not have to remember to check.

**Independent Test**: Create a task with a due date 1 hour from now. Trigger the cron
hook query. Verify the task appears in the returned due-soon list. Mark it done and
re-trigger — verify it no longer appears.

**Acceptance Scenarios**:

1. **Given** a cron trigger fires, **When** the skill's due-soon check is invoked,
   **Then** it returns all tasks that are overdue or due within the look-ahead window
   (default 24 hours) with status not "done" or "cancelled".
2. **Given** no tasks are due soon, **When** the cron hook is invoked, **Then** it
   returns an empty list (no false alerts).
3. **Given** a task is overdue, **When** the cron hook fires, **Then** that task appears
   in results and includes its due date so the agent can compute overdue duration.

---

### Edge Cases

- What happens when a task title is empty or whitespace only? — MUST be rejected with a
  clear error message.
- What if two tasks have the same title? — Allowed; tasks are identified by unique ID.
- What if a due date is set in the past at creation time? — Accepted; the task will
  immediately appear in due-soon queries, which alerts the agent.
- What if the SQLite database file is missing at query time? — MUST surface a clear
  error rather than returning empty results silently.
- What if a category string is no longer used by any task? — No action needed; categories
  are free-text strings on tasks, not a managed entity.
- What if the cron fires but the agent process is not running? — Out of scope; the cron
  hook produces structured output to stdout that the invoking process handles.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The skill MUST allow creation of a task with: title (required), notes
  (optional free text), due date (optional), category (optional string), priority
  (optional: low / normal / high, default: normal), status (auto-set to "new").
- **FR-002**: The skill MUST support the following task statuses: `new`, `in-progress`,
  `blocked`, `done`, `cancelled`.
- **FR-003**: The skill MUST allow updating any editable field of an existing task by ID.
- **FR-004**: The skill MUST allow deletion of a task by ID.
- **FR-005**: The skill MUST support querying tasks with optional filters: status,
  category, due-before date, due-after date, keyword search (title and notes), and a
  show-completed flag (default: exclude done and cancelled tasks).
- **FR-006**: The skill MUST expose a due-soon query returning tasks that are overdue or
  due within a configurable look-ahead window (default 24 hours), excluding done and
  cancelled tasks.
- **FR-007**: The skill MUST record `created_at` and `updated_at` timestamps on every
  task, and `completed_at` when status transitions to "done".
- **FR-008**: The skill MUST store all data in a single SQLite database file local to
  the skill; no external services or secondary databases are permitted.
- **FR-009**: The skill MUST be a valid OpenClaw skill with a `SKILL.md` following the
  AgentSkills frontmatter specification (name, description, metadata eligibility gates).
- **FR-010**: The skill MUST declare `sqlite3` in its `requires.bins` eligibility gate
  so OpenClaw skips activation when the binary is absent.
- **FR-011**: The skill MUST support listing all distinct category values currently
  assigned to tasks, so the agent can offer the human valid choices.
- **FR-012**: The due-soon / cron hook MUST be invocable as a standalone CLI command
  so a system crontab can trigger it and receive structured output without interactive
  agent input.

### Key Entities

- **Task**: `id` (unique identifier), `title` (required text), `notes` (optional text),
  `status` (one of: new / in-progress / blocked / done / cancelled), `priority`
  (low / normal / high), `category` (optional free-text label), `due_at` (optional
  datetime), `created_at`, `updated_at`, `completed_at` (set when status → done).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A human or agent can create, read, update, and delete tasks in a single
  conversation turn with no additional setup beyond skill installation.
- **SC-002**: The due-soon query completes and returns results in under 2 seconds on a
  database containing 10,000 tasks.
- **SC-003**: The cron hook can be triggered from a standard crontab entry and produces
  structured output the agent can parse to compose a user notification, end-to-end with
  no manual steps.
- **SC-004**: All task writes are durable — restarting the agent or host machine does
  not lose any committed task data.
- **SC-005**: The skill activates cleanly on any OpenClaw installation with `sqlite3`
  on PATH, requiring no configuration beyond copying the skill directory into place.

## Assumptions

- `sqlite3` CLI binary is available on PATH on supported platforms; the eligibility gate
  prevents activation where it is absent.
- Due dates are stored and compared in UTC; the agent handles timezone conversion when
  presenting to the human.
- The look-ahead window for due-soon alerts defaults to 24 hours and may be overridden
  by a CLI argument to the cron command.
- Task IDs are auto-assigned at creation; the agent does not supply them.
- No multi-user or authentication layer is needed; the skill runs with the agent's local
  user permissions and serves a single user.
- Priority (low/normal/high) is included to let the agent surface urgent items without
  a separate workflow.
