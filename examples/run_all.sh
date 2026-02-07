#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
CHILD_PID=""

cleanup() {
  echo ""
  echo -e "${RED}Interrupted.${NC}"
  if [ -n "$CHILD_PID" ] && kill -0 "$CHILD_PID" 2>/dev/null; then
    kill -TERM "$CHILD_PID" 2>/dev/null
    wait "$CHILD_PID" 2>/dev/null
  fi
  exit 130
}

trap cleanup INT TERM

header() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

run_example() {
  local name="$1"
  local file="$2"

  echo ""
  echo -e "${YELLOW}▶ ${name}${NC}"
  echo -e "  ${YELLOW}mix run examples/${file}${NC}"
  echo ""

  mix run "examples/${file}" 2>&1 &
  CHILD_PID=$!
  wait "$CHILD_PID"
  local exit_code=$?
  CHILD_PID=""

  echo ""
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✓ ${name}${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ ${name} (exit ${exit_code})${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# Pre-flight
header "AmpSdk Examples Runner"
echo ""
echo "Checking prerequisites..."

if ! command -v amp &> /dev/null; then
  echo -e "${RED}Error: amp CLI not found.${NC}"
  exit 1
fi

AMP_VER="$(amp --version 2>/dev/null | head -1)"
ELIXIR_VER="$(elixir -e 'IO.write(System.version())' 2>/dev/null || echo 'unknown')"

echo -e "  amp CLI:  ${GREEN}${AMP_VER}${NC}"
echo -e "  Elixir:   ${GREEN}${ELIXIR_VER}${NC}"
echo -e "  Project:  ${GREEN}${PROJECT_DIR}${NC}"

header "Compiling"
mix compile --warnings-as-errors

# --- Execute ---
header "Execute"
run_example "Basic Execute (streaming)"        "basic_execute.exs"
run_example "Simple Run (blocking)"            "run_simple.exs"
run_example "Create User Message (multi-turn)" "create_user_message.exs"
run_example "Thinking Mode"                    "thinking.exs"
run_example "No-IDE / Headless Flags"          "no_ide_mode.exs"
run_example "Thread Continuation"              "continue_thread.exs"
run_example "With Permissions"                 "with_permissions.exs"

# --- Management ---
header "Management"
run_example "Usage & Credits"                  "usage.exs"
run_example "Tools List"                       "tools_list.exs"
run_example "Tool Details (Read)"              "tools_show.exs"
run_example "Tools Use (invoke)"               "tools_use.exs"
run_example "Tools Make (interactive)"         "tools_make.exs"
run_example "Skills List"                      "skills_list.exs"
run_example "Skills Manage (add/info/remove)"  "skills_manage.exs"
run_example "Permissions List"                 "permissions_list.exs"
run_example "Permissions Manage (test/add)"    "permissions_manage.exs"
run_example "Tasks List"                       "tasks_list.exs"
run_example "Tasks Import"                     "tasks_import.exs"
run_example "Code Review"                      "review.exs"

# --- Threads ---
header "Threads"
run_example "Thread Create + Markdown"         "threads.exs"
run_example "Thread Lifecycle (rename/share/archive/delete)" "thread_lifecycle.exs"
run_example "Thread List"                      "threads_list.exs"
run_example "Thread Search"                    "threads_search.exs"
run_example "Thread Handoff & Replay"          "threads_handoff_replay.exs"

# --- MCP ---
header "MCP"
run_example "MCP Server List"                  "mcp_list.exs"
run_example "MCP Doctor"                       "mcp_doctor.exs"
run_example "MCP Manage (add/approve/remove)"  "mcp_manage.exs"
run_example "MCP OAuth (status/login/logout)"  "mcp_oauth.exs"

# Summary
header "Results"
TOTAL=$((PASS + FAIL))
echo ""
echo -e "  Total:   ${TOTAL}"
echo -e "  ${GREEN}Passed:  ${PASS}${NC}"
echo -e "  ${RED}Failed:  ${FAIL}${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
  echo -e "${RED}Some examples failed.${NC}"
  exit 1
else
  echo -e "${GREEN}All examples passed.${NC}"
fi
