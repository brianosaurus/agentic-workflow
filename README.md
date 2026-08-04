# Agentic Workflow

A human-gated build pipeline. Claude plans, implements, and verifies; Codex
reviews and audits adversarially; a human approves at every gate.

**This file is the input.** Every stage reads `README.md` as the requirements
source. Fill in [Project brief](#project-brief) below, then run the driver.
Everything above that section is operator documentation — the agents read the
whole file, so keep the brief unambiguous and let it carry the requirements.

---

## Prerequisites

| Tool | Used for | Check |
|---|---|---|
| `claude` | planning, implementation, verification stages | `claude --version` |
| `codex` | adversarial review, manual checklist, final audit | `codex --version` |
| `jq` | rendering the Claude event stream as progress lines | `jq --version` |
| `bash` 3.2+ | the driver (macOS system bash is fine) | `bash --version` |

Codex runs `--sandbox read-only`, so it can never write source. Claude stages
run with an explicit tool allowlist and never with permission-bypass flags.

## Running it

1. Put the project in this repository. The driver resolves its root from the
   script's own location and `cd`s there, so `prompts/`, `scripts/`, the
   brief, and the source tree all live together. To use it on an existing
   codebase, copy `scripts/` and `prompts/` into that repo instead.
2. Write the [Project brief](#project-brief).
3. Start the pipeline:

   ```sh
   ./scripts/agentic-workflow.sh
   ```

4. Answer the gates. Each gate prints the file to review; open it in another
   terminal, come back, and type the exact word requested.

The driver is a resumable state machine. Interrupt it any time and re-run the
same command — it picks up from `.workflow/state`.

## Stages, artifacts, and gates

| # | Stage | Agent | Produces | Gate |
|---|---|---|---|---|
| 1 | Requirements | Claude | `REQUIREMENTS_INTERPRETATION.md` | `APPROVE` |
| 2 | Project plan | Claude | `PROJECT_PLAN.md` | `APPROVE` |
| 3 | Adversarial review | Codex | `ADVERSARIAL_REVIEW.md` | `ACKNOWLEDGE` |
| 4 | Updated plan | Claude | `UPDATED_PROJECT_PLAN.md` | `APPROVE` |
| 5 | Implementation | Claude | source, `IMPLEMENTATION_NOTES.md`, `AUTOMATED_TEST_REPORT.md` | — |
| 6 | Manual checklist | Codex | `MANUAL_CHECKLIST.md` | — |
| 7 | Checklist execution | Claude | `VERIFICATION_REPORT.md`, `DEFECTS.md` | — |
| 8 | Final audit | Codex | `FINAL_AUDIT.md` | — |

`UPDATED_PROJECT_PLAN.md` is the sole plan input to stages 5–8; it must stand
alone, because nothing downstream reads `PROJECT_PLAN.md` or
`ADVERSARIAL_REVIEW.md`. The audit ends in `READY`,
`READY WITH NON-BLOCKING ISSUES`, or `NOT READY`.

Codex-owned artifacts (`ADVERSARIAL_REVIEW.md`, `MANUAL_CHECKLIST.md`,
`FINAL_AUDIT.md`) are never edited by Claude.

## How the gates work

An approval records the SHA-256 of the exact bytes you read, in
`.workflow/approvals/`. Downstream stages re-hash the file and refuse to run if
it changed. Edit an approved document and the pipeline stops until you approve
it again.

Typing anything other than the requested word pauses the workflow and exits
cleanly — state is preserved, so re-running resumes at the same gate.

While you read a gated document, the driver starts the *next* stage in the
background (speculative execution). The result is adopted only if the file is
byte-identical when you approve; any edit during review discards that work and
the stage replays. Implementation is never speculated — it may not begin before
`UPDATED_PROJECT_PLAN.md` is approved.

Disable it with `WORKFLOW_SPECULATE=0` if you routinely edit documents mid-review
or want strictly serial token spend.

## Configuration

All settings are environment variables. Stage keys are the log names:
`REQUIREMENTS`, `PROJECT_PLAN`, `ADVERSARIAL_REVIEW`, `UPDATED_PLAN`,
`IMPLEMENTATION`, `MANUAL_CHECKLIST`, `EXECUTE_CHECKLIST`, `FINAL_AUDIT`.

| Variable | Default | Effect |
|---|---|---|
| `WORKFLOW_SPECULATE` | `1` | Run the next stage during a gate |
| `WORKFLOW_MODEL_<STAGE>` | `opus`; `sonnet` for requirements and checklist execution | Model for one stage |
| `WORKFLOW_EFFORT_<STAGE>` | `high`; `medium` for those two | Reasoning effort |
| `WORKFLOW_TURNS_<STAGE>` | `40`; `200` implementation, `120` checklist execution | Turn cap |
| `WORKFLOW_TOOLS_<STAGE>` | `Read,Glob,Grep,Write` (+ `Edit,TodoWrite,Bash` for implementation and checklist execution) | Tool allowlist |
| `CODEX_MODEL` | Codex default | Model for all Codex stages |

Example:

```sh
WORKFLOW_MODEL_REQUIREMENTS=opus WORKFLOW_TURNS_IMPLEMENTATION=300 \
  ./scripts/agentic-workflow.sh
```

## State and logs

Everything under `.workflow/` is gitignored:

```
.workflow/state              current stage
.workflow/approvals/*.sha256 recorded approvals
.workflow/logs/*.jsonl       raw Claude event streams
.workflow/logs/*.log         Codex transcripts, speculative stage output
.workflow/speculative/       input hashes for speculative stages
```

To redo a stage, write its name into `.workflow/state` and re-run. To start
over, delete `.workflow/` and the generated `*.md` artifacts.

## Troubleshooting

- **"Stage produced no artifact"** — check the log for `[tool ERROR]`; a denied
  `Write` is the usual cause. State did not advance, so re-running replays the
  stage.
- **`[done] error_max_turns`** — raise `WORKFLOW_TURNS_<STAGE>`.
- **"changed after approval"** — the file was edited post-approval; approve it
  again.
- **No output for a long stretch** — implementation legitimately runs long;
  tail `.workflow/logs/implementation.jsonl`.

## Manual helpers

`scripts/workflow.sh` (`approve-plan`, `approve-review`,
`approve-updated-plan`, `status`), `scripts/codex-review-plan.sh`, and
`scripts/codex-create-checklist.sh` drive the same gates by hand. They predate
the unified driver and record approvals in the same place; use them only when
running stages piecemeal.

---

# Project brief

> Replace this entire section with the project. Everything below the heading is
> read as requirements by every agent in the pipeline. Delete the guidance in
> each subsection — leaving it in produces requirements about the template.
>
> Be specific and testable. Vague lines here become ambiguities in
> `REQUIREMENTS_INTERPRETATION.md`, findings in `ADVERSARIAL_REVIEW.md`, and
> guesses in the implementation.

## Summary

One or two sentences: what is being built, and for whom.

## Problem

What is wrong today, and what changes for the user once this exists.

## Scope

What this project covers. Keep it to what must ship.

## Non-goals

What this project explicitly does not do. Name the tempting adjacent features
you are refusing — this is the strongest single lever on scope creep, and the
review stage will cut against it.

## Functional requirements

Number them. Downstream artifacts reference these identifiers, so stable IDs
matter more than prose.

| ID | Requirement | Priority |
|---|---|---|
| R-001 | | Must |
| R-002 | | Should |
| R-003 | | Could |

## User-visible behavior

For each behavior: the trigger, the observable result, and what the user sees
when it fails. "Rejects invalid input" is not a requirement; "rejects a
negative quantity with a 400 and the field name" is.

| ID | Trigger | Expected result | On failure |
|---|---|---|---|
| B-001 | | | |

## Domain rules and invariants

Conditions that must hold at all times, not steps. State each so a test could
falsify it.

| ID | Invariant | Consequence if violated |
|---|---|---|
| I-001 | | |

## Data and state

What the authoritative state is, where it lives, what may hold a cached copy,
and what survives a restart.

## Interfaces

APIs, CLI surface, UI entry points, message formats, external services. Include
the contracts you already control; say so where the shape is open.

## Constraints

Language, runtime, frameworks, libraries that are required or forbidden,
deployment target, performance or size budgets, compatibility that must not
break.

## Failure behavior

What must happen on invalid input, unavailable dependencies, partial writes,
concurrent access, and restart mid-operation. Say which failures must be
visible to the user and which are handled silently.

## Verification

How correctness will be demonstrated: test frameworks, the commands the
implementation stage should run (formatter, type checker, tests, lint, build,
startup smoke), and anything only checkable by hand.

## Definition of done

The concrete conditions under which this is finished. The final audit checks
claims against this list.

## Open questions

Anything genuinely undecided. Listing it here is better than letting an agent
resolve it silently — these surface as assumptions in stage 1 and as findings
in stage 3.
