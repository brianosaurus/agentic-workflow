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
    local wording="${3:-approve}"

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
    read -r -p "Type ${wording^^} exactly to continue: " response

    if [[ "$response" != "${wording^^}" ]]; then
        echo "Gate not accepted. Workflow paused."
        exit 0
    fi

    hash_file "$file" > "$APPROVAL_DIR/${name}.sha256"
    echo "Recorded approval for $file"
}

run_claude() {
    local prompt_file="$1"
    local log_name="$2"

    require_file "$prompt_file"

    echo
    echo "Launching Claude: $log_name"

    claude -p \
        --max-turns 40 \
        "$(cat "$prompt_file")" \
        2>&1 | tee "$LOG_DIR/${log_name}.log"
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
            require_file REQUIREMENTS_INTERPRETATION.md
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
            require_file PROJECT_PLAN.md
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
            require_file UPDATED_PROJECT_PLAN.md
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
            require_file AUTOMATED_TEST_REPORT.md
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
            require_file VERIFICATION_REPORT.md
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
