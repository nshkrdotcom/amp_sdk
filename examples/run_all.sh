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
SKIP=0
FORWARD_ARGS=()
SSH_HOST=""
SSH_AUX_SET=0

cleanup() {
  echo ""
  echo -e "${RED}Interrupted.${NC}"
  exit 130
}

trap cleanup INT TERM

usage() {
  cat <<'EOF'
Usage:
  ./examples/run_all.sh [--cwd PATH] [--danger-full-access] [--ssh-host HOST] [--ssh-user USER] [--ssh-port PORT] [--ssh-identity-file PATH]

Examples:
  ./examples/run_all.sh
  ./examples/run_all.sh --ssh-host example.internal
  ./examples/run_all.sh --ssh-host example.internal --danger-full-access
  ./examples/run_all.sh --ssh-host builder@example.internal --ssh-port 2222
EOF
}

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
  if [ "${#FORWARD_ARGS[@]}" -gt 0 ]; then
    echo -e "  ${YELLOW}mix run examples/${file} -- ${FORWARD_ARGS[*]}${NC}"
  else
    echo -e "  ${YELLOW}mix run examples/${file}${NC}"
  fi
  echo ""

  if [ "${#FORWARD_ARGS[@]}" -gt 0 ]; then
    mix run "examples/${file}" -- "${FORWARD_ARGS[@]}" 2>&1
  else
    mix run "examples/${file}" 2>&1
  fi
  local exit_code=$?

  echo ""
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✓ ${name}${NC}"
    PASS=$((PASS + 1))
  elif [ $exit_code -eq 20 ]; then
    echo -e "${YELLOW}↷ ${name} (skipped)${NC}"
    SKIP=$((SKIP + 1))
  else
    echo -e "${RED}✗ ${name} (exit ${exit_code})${NC}"
    FAIL=$((FAIL + 1))
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --cwd|--ssh-host|--ssh-user|--ssh-port|--ssh-identity-file)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires a value." >&2
        exit 1
      fi

      if [[ "$1" == "--ssh-host" ]]; then
        SSH_HOST="$2"
      elif [[ "$1" == --ssh-* ]]; then
        SSH_AUX_SET=1
      fi

      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --cwd=*|--ssh-host=*|--ssh-user=*|--ssh-port=*|--ssh-identity-file=*)
      if [[ "$1" == --ssh-host=* ]]; then
        SSH_HOST="${1#*=}"
      elif [[ "$1" == --ssh-* ]]; then
        SSH_AUX_SET=1
      fi

      FORWARD_ARGS+=("$1")
      shift
      ;;
    --danger-full-access)
      FORWARD_ARGS+=("$1")
      shift
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SSH_HOST" && "$SSH_AUX_SET" -eq 1 ]]; then
  echo "Error: --ssh-user/--ssh-port/--ssh-identity-file require --ssh-host." >&2
  exit 1
fi

# Pre-flight
header "AmpSdk Examples Runner"
echo ""
echo "Checking prerequisites..."

ELIXIR_VER="$(elixir -e 'IO.write(System.version())' 2>/dev/null || echo 'unknown')"

echo -e "  Elixir:   ${GREEN}${ELIXIR_VER}${NC}"
echo -e "  Project:  ${GREEN}${PROJECT_DIR}${NC}"

if [[ -n "$SSH_HOST" ]]; then
  echo -e "  Surface:  ${GREEN}ssh_exec host=${SSH_HOST}${NC}"
else
  if ! command -v amp &> /dev/null; then
    echo -e "${RED}Error: amp CLI not found.${NC}"
    exit 1
  fi

  AMP_VER="$(amp --version 2>/dev/null | head -1)"
  echo -e "  amp CLI:  ${GREEN}${AMP_VER}${NC}"
fi

if [[ " ${FORWARD_ARGS[*]} " == *" --danger-full-access "* ]]; then
  echo -e "  Runtime:  ${GREEN}dangerously_allow_all${NC}"
fi

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
TOTAL=$((PASS + FAIL + SKIP))
echo ""
echo -e "  Total:   ${TOTAL}"
echo -e "  ${GREEN}Passed:  ${PASS}${NC}"
echo -e "  ${YELLOW}Skipped: ${SKIP}${NC}"
echo -e "  ${RED}Failed:  ${FAIL}${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
  echo -e "${RED}Some examples failed.${NC}"
  exit 1
else
  echo -e "${GREEN}All examples passed.${NC}"
fi
