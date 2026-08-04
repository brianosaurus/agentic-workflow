#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STATE_DIR=".workflow"
APPROVAL_DIR="$STATE_DIR/approvals"
LOG_DIR="$STATE_DIR/logs"
STATE_FILE="$STATE_DIR/state"

mkdir -p "$APPROVAL_DIR" "$LOG_DIR"

hash_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

# bash 3.2 (macOS system bash) has no ${var^^}.
upper() {
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

set_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

get_state() {
    if [[ -s "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "REQUIREMENTS"
    fi
}

require_file() {
    if [[ ! -s "$1" ]]; then
        echo "Required file is missing or empty: $1"
        exit 1
    fi
}

# Used after an agent stage: a missing artifact here usually means a denied
# tool, not a refusal to work.
require_artifact() {
    if [[ ! -s "$1" ]]; then
        echo
        echo "Stage produced no artifact: $1"
        echo "Check the log for '[tool ERROR]' lines — a denied Write is the"
        echo "most common cause. Grant the tool and re-run; state has not"
        echo "advanced, so the stage replays cleanly."
        exit 1
    fi
}

verify_approval() {
    local file="$1"
    local name="$2"
    local approval="$APPROVAL_DIR/${name}.sha256"

    require_file "$file"
    require_file "$approval"

    local expected
    local actual

    expected="$(cat "$approval")"
    actual="$(hash_file "$file")"

    if [[ "$expected" != "$actual" ]]; then
        echo "$file changed after approval."
        echo "Review and approve it again."
        exit 1
    fi
}

review_and_approve() {
    local file="$1"
    local name="$2"
    local wording
    wording="$(upper "${3:-approve}")"

    require_file "$file"

    echo
    echo "=================================================="
    echo "HUMAN REVIEW REQUIRED: $file"
    echo "=================================================="
    echo
    echo "Review in another terminal with:"
    echo
    echo "  less $file"
    echo
    echo "or:"
    echo
    echo "  code $file"
    echo

    read -r -p "Press ENTER after reviewing the file..."

    echo
    read -r -p "Type $wording exactly to continue: " response

    if [[ "$response" != "$wording" ]]; then
        echo "Gate not accepted. Workflow paused."
        exit 0
    fi

    hash_file "$file" > "$APPROVAL_DIR/${name}.sha256"
    echo "Recorded approval for $file"
}

# Render the stream-json event feed as readable progress lines.
# Non-JSON lines (startup warnings) are dropped rather than fataling jq.
format_claude_stream() {
    jq -R -r --unbuffered '
        (fromjson? // empty) as $e
        | if $e.type == "assistant" then
              ($e.message.content[]?
               | if .type == "text" then .text
                 elif .type == "tool_use" then "  [tool] \(.name)"
                 else empty end)
          elif $e.type == "user" then
              ($e.message.content[]?
               | select(.type == "tool_result" and .is_error == true)
               | .content
               | (if type == "array" then map(.text? // "") | join(" ")
                  else tostring end)
               | "  [tool ERROR] \(.[0:200])")
          elif $e.type == "result" then
              "\n[done] \($e.subtype) — \($e.num_turns) turns, \($e.duration_ms / 1000 | floor)s"
          else empty end
    '
}

# Tool grants. In -p mode there is no interactive prompt, so anything not
# granted here is auto-denied — and the stage only discovers that after doing
# all of its work. Never use --dangerously-skip-permissions (CLAUDE.md rule 8).
#
# Bash is granted broadly because the implementation stage must run cargo,
# fmt, clippy, and the test suite. Tightening this to a command allowlist is
# viable, but every omission costs a full stage re-run to discover.
# Pass a third argument to run_claude to override per stage.
AGENT_TOOLS="Read,Glob,Grep,Write,Edit,TodoWrite,Bash"

run_claude() {
    local prompt_file="$1"
    local log_name="$2"
    local tools="${3:-$AGENT_TOOLS}"

    require_file "$prompt_file"

    echo
    echo "Launching Claude: $log_name"
    echo "Tools: $tools"
    echo

    # Plain `claude -p` buffers the entire session and prints nothing until it
    # exits, which is indistinguishable from a hang. Stream events instead.
    #
    # The prompt goes in on stdin, not as a positional argument: --allowedTools
    # is variadic and silently swallows a trailing prompt argument, which fails
    # with "Input must be provided either through stdin or as a prompt argument".
    local status=0
    claude -p \
        --max-turns 200 \
        --output-format stream-json \
        --verbose \
        --allowedTools "$tools" \
        < "$prompt_file" \
        2>&1 \
        | tee "$LOG_DIR/${log_name}.jsonl" \
        | format_claude_stream || status=$?

    if [[ "$status" -ne 0 ]]; then
        echo "Claude exited with status $status."
        echo "Raw event log: $LOG_DIR/${log_name}.jsonl"
        exit "$status"
    fi
}

run_codex_review() {
    local prompt_file="$1"
    local output_file="$2"
    local log_name="$3"

    require_file "$prompt_file"

    echo
    echo "Launching Codex: $log_name"

    # Keep the reviewer read-only. The shell writes Codex's final message
    # into the designated review artifact.
    codex exec \
        --ephemeral \
        --sandbox read-only \
        --output-last-message "$output_file" \
        "$(cat "$prompt_file")" \
        2>&1 | tee "$LOG_DIR/${log_name}.log"

    require_file "$output_file"
}

while true; do
    state="$(get_state)"

    echo
    echo "Current workflow state: $state"

    case "$state" in
        REQUIREMENTS)
            run_claude prompts/requirements.md requirements
            require_artifact REQUIREMENTS_INTERPRETATION.md
            set_state WAIT_REQUIREMENTS_APPROVAL
            ;;

        WAIT_REQUIREMENTS_APPROVAL)
            review_and_approve \
                REQUIREMENTS_INTERPRETATION.md \
                REQUIREMENTS_INTERPRETATION \
                approve
            set_state PROJECT_PLAN
            ;;

        PROJECT_PLAN)
            verify_approval \
                REQUIREMENTS_INTERPRETATION.md \
                REQUIREMENTS_INTERPRETATION
            run_claude prompts/project-plan.md project-plan
            require_artifact PROJECT_PLAN.md
            set_state WAIT_PLAN_APPROVAL
            ;;

        WAIT_PLAN_APPROVAL)
            review_and_approve PROJECT_PLAN.md PROJECT_PLAN approve
            set_state ADVERSARIAL_REVIEW
            ;;

        ADVERSARIAL_REVIEW)
            verify_approval PROJECT_PLAN.md PROJECT_PLAN
            run_codex_review \
                prompts/adversarial-review.md \
                ADVERSARIAL_REVIEW.md \
                adversarial-review
            set_state WAIT_REVIEW_ACKNOWLEDGEMENT
            ;;

        WAIT_REVIEW_ACKNOWLEDGEMENT)
            review_and_approve \
                ADVERSARIAL_REVIEW.md \
                ADVERSARIAL_REVIEW \
                acknowledge
            set_state UPDATED_PLAN
            ;;

        UPDATED_PLAN)
            verify_approval PROJECT_PLAN.md PROJECT_PLAN
            verify_approval \
                ADVERSARIAL_REVIEW.md \
                ADVERSARIAL_REVIEW
            run_claude prompts/updated-plan.md updated-plan
            require_artifact UPDATED_PROJECT_PLAN.md
            set_state WAIT_UPDATED_PLAN_APPROVAL
            ;;

        WAIT_UPDATED_PLAN_APPROVAL)
            review_and_approve \
                UPDATED_PROJECT_PLAN.md \
                UPDATED_PROJECT_PLAN \
                approve
            set_state IMPLEMENT
            ;;

        IMPLEMENT)
            verify_approval \
                UPDATED_PROJECT_PLAN.md \
                UPDATED_PROJECT_PLAN
            run_claude prompts/implement.md implementation
            require_artifact AUTOMATED_TEST_REPORT.md
            set_state MANUAL_CHECKLIST
            ;;

        MANUAL_CHECKLIST)
            run_codex_review \
                prompts/manual-checklist.md \
                MANUAL_CHECKLIST.md \
                manual-checklist
            set_state EXECUTE_CHECKLIST
            ;;

        EXECUTE_CHECKLIST)
            run_claude prompts/execute-checklist.md execute-checklist
            require_artifact VERIFICATION_REPORT.md
            set_state FINAL_AUDIT
            ;;

        FINAL_AUDIT)
            run_codex_review \
                prompts/final-audit.md \
                FINAL_AUDIT.md \
                final-audit
            set_state COMPLETE
            ;;

        COMPLETE)
            echo
            echo "Workflow complete."
            echo
            echo "Artifacts:"
            echo "  REQUIREMENTS_INTERPRETATION.md"
            echo "  PROJECT_PLAN.md"
            echo "  ADVERSARIAL_REVIEW.md"
            echo "  UPDATED_PROJECT_PLAN.md"
            echo "  IMPLEMENTATION_NOTES.md"
            echo "  AUTOMATED_TEST_REPORT.md"
            echo "  MANUAL_CHECKLIST.md"
            echo "  VERIFICATION_REPORT.md"
            echo "  FINAL_AUDIT.md"
            exit 0
            ;;

        *)
            echo "Unknown workflow state: $state"
            exit 1
            ;;
    esac
done
