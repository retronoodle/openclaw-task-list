#!/usr/bin/env bash
# test-query-filter.sh — US2: Query and Filter Tasks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/../scripts"

# Isolated temp DB — never touches the real tasks.db
TASK_LIST_DB="$(mktemp -t task-list-test.XXXXXX)"
export TASK_LIST_DB
trap 'rm -f "${TASK_LIST_DB}"' EXIT

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "    $2"; FAIL=$((FAIL + 1)); }

# Count tasks by counting "id": occurrences in JSON array
count_tasks() {
    local json="$1"
    if printf '%s' "$json" | grep -q '"id":'; then
        printf '%s' "$json" | grep -o '"id":' | wc -l | tr -d ' '
    else
        echo 0
    fi
}

assert_count() {
    local desc="$1" json="$2" expected="$3"
    local actual; actual=$(count_tasks "$json")
    if [ "$actual" -eq "$expected" ]; then
        pass "$desc"
    else
        fail "$desc" "expected ${expected} tasks, got ${actual} in: ${json}"
    fi
}

assert_contains() {
    local desc="$1" json="$2" text="$3"
    if printf '%s' "$json" | grep -qF "$text"; then
        pass "$desc"
    else
        fail "$desc" "expected to find '${text}' in: ${json}"
    fi
}

assert_not_contains() {
    local desc="$1" json="$2" text="$3"
    if ! printf '%s' "$json" | grep -qF "$text"; then
        pass "$desc"
    else
        fail "$desc" "expected NOT to find '${text}' in: ${json}"
    fi
}

echo "=== test-query-filter.sh ==="
echo ""

# Initialize DB and seed 5 tasks with varied status/category/notes/due_at
"${SCRIPTS_DIR}/db-init.sh"

# 1: new, work, due 2026-03-15 (later due date)
"${SCRIPTS_DIR}/task-create.sh" --title "Alpha work task" --category work --due-at "2026-03-15T12:00:00Z" > /dev/null

# 2: in-progress, personal, no due, has notes
"${SCRIPTS_DIR}/task-create.sh" --title "Beta personal task" --category personal --notes "meeting notes here" > /dev/null
id2=$(sqlite3 "${TASK_LIST_DB}" "SELECT id FROM tasks WHERE title='Beta personal task';")
"${SCRIPTS_DIR}/task-update.sh" --id "$id2" --status in-progress > /dev/null

# 3: done, work, no due
"${SCRIPTS_DIR}/task-create.sh" --title "Gamma work done" --category work > /dev/null
id3=$("${SCRIPTS_DIR}/task-list.sh" --status new --show-completed 2>/dev/null | grep -o '"id":[0-9]*' | tail -1 | grep -o '[0-9]*' || true)
# Re-seed id for task 3 via db directly — get it from db
id3=$(sqlite3 "${TASK_LIST_DB}" "SELECT id FROM tasks WHERE title='Gamma work done';")
"${SCRIPTS_DIR}/task-update.sh" --id "$id3" --status done > /dev/null

# 4: cancelled, errands, no due
"${SCRIPTS_DIR}/task-create.sh" --title "Delta cancelled task" --category errands > /dev/null
id4=$(sqlite3 "${TASK_LIST_DB}" "SELECT id FROM tasks WHERE title='Delta cancelled task';")
"${SCRIPTS_DIR}/task-update.sh" --id "$id4" --status cancelled > /dev/null

# 5: blocked, errands, due 2026-03-10 (earlier due date), has keyword in notes
"${SCRIPTS_DIR}/task-create.sh" --title "Epsilon errands task" --category errands --notes "contains keyword value" --due-at "2026-03-10T12:00:00Z" > /dev/null

# ── Test (a): no-filter excludes done/cancelled ───────────────────────────────
echo "Test (a): no filter excludes done and cancelled"
out=$("${SCRIPTS_DIR}/task-list.sh")
assert_count       "active tasks count is 3"        "$out" 3
assert_contains    "new task included"               "$out" "Alpha work task"
assert_contains    "in-progress task included"       "$out" "Beta personal task"
assert_contains    "blocked task included"           "$out" "Epsilon errands task"
assert_not_contains "done task excluded"             "$out" "Gamma work done"
assert_not_contains "cancelled task excluded"        "$out" "Delta cancelled task"

# ── Test (b): --status filter ─────────────────────────────────────────────────
echo "Test (b): --status filter"
out=$("${SCRIPTS_DIR}/task-list.sh" --status in-progress)
assert_count    "one in-progress task"          "$out" 1
assert_contains "correct task returned"         "$out" "Beta personal task"

# ── Test (c): --category filter ───────────────────────────────────────────────
echo "Test (c): --category filter"
out=$("${SCRIPTS_DIR}/task-list.sh" --category work)
assert_count       "one active work task"           "$out" 1
assert_contains    "alpha work task included"        "$out" "Alpha work task"
assert_not_contains "done task excluded by default"  "$out" "Gamma work done"

# ── Test (d): --due-before filter ─────────────────────────────────────────────
echo "Test (d): --due-before filter"
out=$("${SCRIPTS_DIR}/task-list.sh" --due-before "2026-03-12T00:00:00Z")
assert_count       "one task due before 2026-03-12" "$out" 1
assert_contains    "epsilon task included"           "$out" "Epsilon errands task"
assert_not_contains "alpha task excluded"            "$out" "Alpha work task"

# ── Test (e): --keyword matches title and notes ───────────────────────────────
echo "Test (e): --keyword search"
out=$("${SCRIPTS_DIR}/task-list.sh" --keyword "meeting")
assert_count    "keyword matches notes"          "$out" 1
assert_contains "beta task found via notes"      "$out" "Beta personal task"

out2=$("${SCRIPTS_DIR}/task-list.sh" --keyword "keyword")
assert_count    "keyword in notes matched"       "$out2" 1
assert_contains "epsilon task found via notes"   "$out2" "Epsilon errands task"

out3=$("${SCRIPTS_DIR}/task-list.sh" --keyword "work task")
assert_count    "keyword in title matched"       "$out3" 1
assert_contains "alpha task found via title"     "$out3" "Alpha work task"

# ── Test (f): --show-completed includes done/cancelled ────────────────────────
echo "Test (f): --show-completed includes done and cancelled"
out=$("${SCRIPTS_DIR}/task-list.sh" --show-completed)
assert_count    "all 5 tasks returned"           "$out" 5
assert_contains "done task included"             "$out" "Gamma work done"
assert_contains "cancelled task included"        "$out" "Delta cancelled task"

# ── Test (g): default ordering — due_at ASC nulls last, then created_at ASC ───
echo "Test (g): default ordering"
out=$("${SCRIPTS_DIR}/task-list.sh")
# Epsilon (due 2026-03-10) should appear before Alpha (due 2026-03-15)
epsilon_pos=$(printf '%s' "$out" | grep -bo "Epsilon" | head -1 | cut -d: -f1 || echo 9999)
alpha_pos=$(printf '%s' "$out" | grep -bo "Alpha" | head -1 | cut -d: -f1 || echo 9999)
# Beta has no due_at, should appear after both
beta_pos=$(printf '%s' "$out" | grep -bo "Beta" | head -1 | cut -d: -f1 || echo 9999)
if [ "$epsilon_pos" -lt "$alpha_pos" ]; then
    pass "earlier due_at appears before later due_at"
else
    fail "earlier due_at appears before later due_at" "epsilon_pos=${epsilon_pos} alpha_pos=${alpha_pos}"
fi
if [ "$alpha_pos" -lt "$beta_pos" ]; then
    pass "tasks with due_at appear before tasks without"
else
    fail "tasks with due_at appear before tasks without" "alpha_pos=${alpha_pos} beta_pos=${beta_pos}"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
