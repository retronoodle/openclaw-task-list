<!--
SYNC IMPACT REPORT
==================
Version change: (template/unversioned) → 1.0.0
Bump rationale: MINOR — initial population of all placeholders; first ratified version.
Modified principles: N/A (initial population from template)
Added sections:
  - Core Principles (5 principles defined)
  - Technical Standards
  - Quality Gates
  - Governance
Removed sections: None (template placeholders replaced)
Templates reviewed:
  - .specify/templates/plan-template.md  ✅ Constitution Check section is dynamic — no changes needed
  - .specify/templates/spec-template.md  ✅ Structure compatible with these principles
  - .specify/templates/tasks-template.md ✅ Phase/story structure aligns with skill-first and test-first principles
  - .specify/templates/agent-file-template.md ✅ No outdated principle references
Deferred TODOs: None.
-->

# OpenClaw Task List Constitution

## Core Principles

### I. OpenClaw Skill Compatibility (NON-NEGOTIABLE)

This project MUST be implemented as a valid OpenClaw skill following the AgentSkills
specification. The `SKILL.md` file is the canonical entry point and MUST be present in
the skill root directory. YAML frontmatter MUST declare `name` and `description`. All
optional metadata MUST be declared via the `metadata.openclaw` eligibility gate block.
No implementation detail MUST require modification of the OpenClaw host installation.
The skill MUST be drop-in compatible with any standard OpenClaw workspace.

**Rationale**: Portability across OpenClaw installations is a first-class requirement.
Any deviation from the AgentSkills spec breaks that compatibility guarantee.

### II. Self-Contained SQLite Storage

All persistent data MUST be stored in a single SQLite database file local to the skill.
The database path MUST be deterministic and declared — no runtime discovery or
user-supplied paths. No external services, network calls, or secondary databases are
permitted. The `sqlite3` binary MUST be declared in `metadata.openclaw.requires.bins`
so OpenClaw gates skill activation on its presence.

**Rationale**: Self-containment ensures the skill works offline, leaves no external
footprint, and can be cleanly uninstalled by removing its directory and DB file.

### III. Security — No Injection (NON-NEGOTIABLE)

All user-supplied input MUST be passed to SQLite as parameterized values — never
interpolated into SQL strings. Bash tool invocations MUST use argument arrays or
properly quoted/escaped variables; raw string interpolation of user data into shell
commands is forbidden. Input validation MUST occur at the skill boundary before any
storage or shell operation.

**Rationale**: Skills execute with user-level permissions. SQL or shell injection through
task content would be a critical vulnerability in a tool that handles arbitrary text.

### IV. Portability and Eligibility Declarations

The skill MUST declare every external binary dependency in
`metadata.openclaw.requires.bins`. If OS-specific behaviour is needed, it MUST be gated
via `metadata.openclaw.os`. The skill MUST function on any platform declared in `os`
without requiring host-level configuration beyond what OpenClaw's standard setup
provides. No assumptions about the host environment beyond Node 22+ and OpenClaw
installed may be made.

**Rationale**: OpenClaw users expect skills to either work or declare clearly why they
cannot. Silent failures due to undeclared dependencies violate the platform contract.

### V. Simplicity (YAGNI)

The minimum schema, commands, and UI surface MUST be implemented to satisfy the current
user stories. Abstractions MUST NOT be introduced for hypothetical future needs. The
SQLite schema MUST start with a single `tasks` table; additional tables require
documented justification. Complexity MUST be explicitly recorded in the plan's
Complexity Tracking table.

**Rationale**: Task list skills accrue scope quickly. Strict YAGNI discipline keeps the
SKILL.md instructions clear and the codebase auditable.

## Technical Standards

- **SKILL.md frontmatter** MUST use single-line keys; multi-line values are not supported
  by the OpenClaw parser.
- **Database file** MUST reside at a path relative to or alongside the skill directory
  (e.g., `~/.openclaw/skills/task-list/tasks.db`), documented in SKILL.md.
- **Tool dispatch**: Use `command-dispatch: tool` for direct CRUD operations that do not
  require model reasoning. Reserve model-reasoned dispatch for natural-language queries.
- **Bash tools**: MUST use parameterized sqlite3 invocations (e.g., pipe SQL with bound
  parameters or use named placeholders) — never string-concatenated queries.
- **Schema migrations**: Any schema change MUST include an `ALTER TABLE` or migration
  script; destructive migrations MUST be version-gated and documented.
- **Error output**: Errors MUST be returned as structured tool content (type: "text")
  with a clear message — never silent failures or empty responses.

## Quality Gates

All features MUST pass the following gates before being considered complete:

1. **Skill loads cleanly** — `openclaw agent --message "use task-list skill"` MUST
   succeed without errors on a clean OpenClaw installation with sqlite3 on PATH.
2. **Eligibility gates declared** — `requires.bins` in frontmatter MUST match every
   external binary actually used.
3. **No injection vectors** — All SQL queries MUST use parameterized statements;
   verified by code review and/or test.
4. **Tests pass** — If tests are specified in the feature plan, they MUST be written
   to fail first, then pass after implementation (Red-Green-Refactor).
5. **No placeholders remain** — No `[NEEDS CLARIFICATION]` or `TODO` tokens in
   shipped code or SKILL.md.

## Governance

This Constitution supersedes all other development practices for this project.
Amendments MUST follow this procedure:

1. **Propose** — Document the amendment and its rationale in a pull request or written
   record.
2. **Review** — At least one additional reviewer MUST approve, or the author MUST
   self-document the rationale if working solo.
3. **Migration** — Features violating a new principle MUST include a remediation plan
   or an explicit deferral with TODO.
4. **Version bump** — Follow semantic versioning:
   - MAJOR: Principle removal, redefinition, or backward-incompatible governance change.
   - MINOR: New principle or section added, or material guidance expansion.
   - PATCH: Clarifications, wording, or non-semantic refinements.
5. **Update `LAST_AMENDED_DATE`** and propagate changes to dependent templates per the
   Sync Impact Report format at the top of this file.

All feature plans MUST include a Constitution Check section confirming compliance with
all five principles before implementation begins. Complexity violations MUST be logged
in the plan's Complexity Tracking table.

**Version**: 1.0.0 | **Ratified**: 2026-03-05 | **Last Amended**: 2026-03-05
