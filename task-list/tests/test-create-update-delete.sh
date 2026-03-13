#!/usr/bin/env bash
# test-create-update-delete.sh — US1: Create, Read, Update, Delete tasks
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

# assert_json_field JSON KEY EXPECTED_VALUE
# Matches both string ("key":"val") and bare (key:val / key:null / key:true)
assert_json_field() {
    local desc="$1" json="$2" key="$3" expected="$4"
    if printf '%s' "$json" | grep -qF "\"${key}\":\"${expected}\"" || \
       printf '%s' "$json" | grep -qF "\"${key}\":${expected}"; then
        pass "$desc"
    else
        fail "$desc" "key=${key} expected=${expected} in: ${json}"
    fi
}

# assert_field_set JSON KEY — key has a non-null string value
assert_field_set() {
    local desc="$1" json="$2" key="$3"
    if printf '%s' "$json" | grep -qE "\"${key}\":\"[^\"]+\""; then
        pass "$desc"
    else
        fail "$desc" "expected non-null string for key=${key} in: ${json}"
    fi
}

# assert_field_null JSON KEY — key has value null
assert_field_null() {
    local desc="$1" json="$2" key="$3"
    if printf '%s' "$json" | grep -qF "\"${key}\":null"; then
        pass "$desc"
    else
        fail "$desc" "expected null for key=${key} in: ${json}"
    fi
}

echo "=== test-create-update-delete.sh ==="
echo ""

# Initialize DB
"${SCRIPTS_DIR}/db-init.sh"

# ── Test (a): create with title only ─────────────────────────────────────────
echo "Test (a): create with title only"
out=$("${SCRIPTS_DIR}/task-create.sh" --title "Test Task")
id=$(printf '%s' "$out" | grep -oE '"id":[0-9]+' | grep -oE '[0-9]+')
assert_json_field "status is new"       "$out" "status"   "new"
assert_json_field "priority is normal"  "$out" "priority" "normal"
assert_json_field "title is set"        "$out" "title"    "Test Task"
[ -n "$id" ] && pass "id is present ($id)" || fail "id is present" "no id in: $out"

# ── Test (b): blank title rejected ───────────────────────────────────────────
echo "Test (b): blank title rejected"
if "${SCRIPTS_DIR}/task-create.sh" --title "   " 2>/dev/null; then
    fail "blank title rejected" "expected exit 1, got exit 0"
else
    pass "blank title rejected"
fi

# ── Test (c): update status to done → completed_at set ───────────────────────
echo "Test (c): update status to done sets completed_at"
out=$("${SCRIPTS_DIR}/task-update.sh" --id "$id" --status done)
assert_json_field "status is done"  "$out" "status" "done"
assert_field_set  "completed_at set" "$out" "completed_at"

# ── Test (d): update status away from done → completed_at cleared ────────────
echo "Test (d): update status away from done clears completed_at"
out=$("${SCRIPTS_DIR}/task-update.sh" --id "$id" --status "in-progress")
assert_json_field "status is in-progress" "$out" "status" "in-progress"
assert_field_null "completed_at cleared"  "$out" "completed_at"

# ── Test (e): delete returns deleted:true ────────────────────────────────────
echo "Test (e): delete returns deleted:true"
out=$("${SCRIPTS_DIR}/task-delete.sh" --id "$id")
assert_json_field "deleted is true"  "$out" "deleted" "true"
assert_json_field "deleted id matches" "$out" "id" "$id"

# ── Test (f): get after delete returns error ──────────────────────────────────
echo "Test (f): get after delete returns error"
if "${SCRIPTS_DIR}/task-get.sh" --id "$id" 2>/dev/null; then
    fail "get after delete errors" "expected exit 1, got exit 0"
else
    pass "get after delete errors"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
