# Agentic Workflow

> Governed CI for coding agents.
>
> Everyone else is building agents that run unsupervised. This is the approval
> layer that makes them acceptable in production.

Agentic Workflow is a human-gated, adversarially-audited CI pipeline for
AI-generated code. A primary agent plans, implements, and verifies; an
independent reviewer audits adversarially; a human approves at every gate.
By default the primary agent is `claude` and the reviewer is `codex`, but both
are configurable (e.g., `kimi` + `codex`). Approved artifacts are SHA-256 pinned
and reviewer-owned files are immutable, so what ships is exactly what was
reviewed.

What makes this different from a generic agent framework:

- **Human approval gates** at every planning and review stage.
- **Adversarial review** by a second model that did not write the code.
- **SHA-256 pinned specs** so approved artifacts cannot be silently modified.
- **Immutable reviewer-owned files** that the implementing agent cannot edit.
- **Speculative execution** that is adopted only if the spec remains
  byte-identical.

Use it when the cost of an agent silently shipping the wrong thing is higher
than the cost of waiting for a human to say yes.

New users should start with [`QUICK_START.md`](QUICK_START.md). For the design
philosophy behind the gates, read [`AGENTIC.md`](AGENTIC.md).

**This file is the input.** Every stage reads `README.md` as the requirements
source. Fill in [Project brief](#project-brief) below, then run the driver.
Everything above that section is operator documentation — the agents read the
whole file, so keep the brief unambiguous and let it carry the requirements.

---

## Workflows

This repository contains two gated pipelines:

| Workflow | Script | Input | Use case |
|---|---|---|---|
| **New application** | `./scripts/agentic-workflow.sh` | [Project brief](#project-brief) in `README.md` | Build a new project from requirements. |
| **Change request** | `./scripts/change-workflow.sh` | `CHANGE_REQUEST.md` | Modify an existing codebase with baseline, spec, plan, and audit. |

Both pipelines share the same gate model: the primary agent plans/implements/
verifies, the reviewer adversarially audits, and you approve every gate.
Artifacts are SHA-256 pinned; reviewer-owned files are immutable to the primary
agent.

### Starting from a GitHub issue

If the request is already in a GitHub issue, seed the right workflow from the
issue number or URL:

```sh
# Defaults to new-app if the repo looks empty, change-request if it looks like
# an existing codebase.
./scripts/from-issue.sh 52638
./scripts/from-issue.sh https://github.com/owner/repo/issues/52638

# Force the mode explicitly:
./scripts/from-issue.sh 52638 --change
./scripts/from-issue.sh https://github.com/owner/repo/issues/52638 --new
```

`--change` writes `CHANGE_REQUEST.md` from the issue title and body.
`--new` replaces the [Project brief](#project-brief) section of `README.md`.
Requires the `gh` CLI or `curl`.

---

## Prerequisites

| Tool | Used for | Check |
|---|---|---|
| Primary agent CLI (default `claude`) | planning, implementation, verification stages | `claude --version` |
| Reviewer CLI (default `codex`) | adversarial review, manual checklist, final audit | `codex --version` |
| `jq` | rendering the agent event stream as progress lines | `jq --version` |
| `bash` 3.2+ | the driver (macOS system bash is fine) | `bash --version` |

The reviewer CLI runs with `--sandbox read-only` and `--ephemeral`, so it can
never write source. Primary-agent stages run with an explicit tool allowlist and
never with permission-bypass flags.

## Running it

### New application

1. Put the project in this repository. The driver resolves its root from the
   script's own location and `cd`s there, so `prompts/`, `scripts/`, the
   brief, and the source tree all live together.
2. Write the [Project brief](#project-brief) in this file.
3. Start the pipeline:

   ```sh
   ./scripts/agentic-workflow.sh
   ```

4. Answer the gates. Each gate prints the file to review; open it in another
   terminal, come back, and type the exact word requested.

### Change request

1. Copy `scripts/`, `prompts/`, `CLAUDE.md`, and `CHANGE_REQUEST.md` into the
   target repository, or run directly if you are already in a checkout that
   contains the workflow files.
2. Fill in `CHANGE_REQUEST.md`. Use `./scripts/from-issue.sh` to seed it from a
   GitHub issue.
3. Commit or stash unrelated work — the driver records `git diff` of the whole
   working tree as the authoritative change record.
4. Start the pipeline:

   ```sh
   ./scripts/change-workflow.sh
   ```

The `change-workflow.sh` driver supports a `full` track (separate baseline,
spec, and plan stages) and a `small` track that collapses them into one call
for focused changes:

```sh
WORKFLOW_TRACK=small ./scripts/change-workflow.sh
```

Both drivers are resumable state machines. Interrupt them and re-run the same
command — they pick up from `.workflow/state`.

## Stages, artifacts, and gates

### New application

| # | Stage | Agent | Produces | Gate |
|---|---|---|---|---|
| 1 | Requirements | Primary agent | `REQUIREMENTS_INTERPRETATION.md` | `APPROVE` |
| 2 | Project plan | Primary agent | `PROJECT_PLAN.md` | `APPROVE` |
| 3 | Adversarial review | Reviewer | `ADVERSARIAL_REVIEW.md` | `ACKNOWLEDGE` |
| 4 | Updated plan | Primary agent | `UPDATED_PROJECT_PLAN.md` | `APPROVE` |
| 5 | Implementation | Primary agent | source, `IMPLEMENTATION_NOTES.md`, `AUTOMATED_TEST_REPORT.md` | — |
| 6 | Manual checklist | Reviewer | `MANUAL_CHECKLIST.md` | — |
| 7 | Checklist execution | Primary agent | `VERIFICATION_REPORT.md`, `DEFECTS.md` | — |
| 8 | Final audit | Reviewer | `FINAL_AUDIT.md` | — |

`UPDATED_PROJECT_PLAN.md` is the sole plan input to stages 5–8; it must stand
alone, because nothing downstream reads `PROJECT_PLAN.md` or
`ADVERSARIAL_REVIEW.md`.

### Change request

| State | Agent | Produces | Gate |
|---|---|---|---|
| `ANALYZE` | Primary agent | `BASELINE_REPORT.md`, `CHANGE_SPEC.md` | `APPROVE` |
| `PLAN` | Primary agent + reviewer | `CHANGE_PLAN.md`, `ADVERSARIAL_REVIEW.md` | `ACKNOWLEDGE` |
| `UPDATED_PLAN` | Primary agent | `UPDATED_CHANGE_PLAN.md` | `APPROVE` |
| `IMPLEMENT` | Primary agent + reviewer | source, `IMPLEMENTATION_NOTES.md`, `CHANGE_TEST_REPORT.md` | — |
| `CHECKLIST` | Reviewer | `MANUAL_CHECKLIST.md` | — |
| `EXECUTE_CHECKLIST` | Primary agent | `VERIFICATION_REPORT.md`, `DEFECTS.md` | — |
| `FINAL_AUDIT` | Reviewer | `FINAL_AUDIT.md` | — |

`UPDATED_CHANGE_PLAN.md` is the sole plan input to implementation and
verification. The reviewer writes the verification checklist concurrently
during implementation from the frozen, approved artifacts so it cannot race the
primary agent's edits.

Both pipelines end in `READY`, `READY WITH NON-BLOCKING ISSUES`, or `NOT READY`.

Reviewer-owned artifacts (`ADVERSARIAL_REVIEW.md`, `MANUAL_CHECKLIST.md`,
`FINAL_AUDIT.md`) are never edited by the primary agent.

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
the approved updated plan (`UPDATED_PROJECT_PLAN.md` or
`UPDATED_CHANGE_PLAN.md`) is in place.

Disable it with `WORKFLOW_SPECULATE=0` if you routinely edit documents mid-review
or want strictly serial token spend.

## Configuration

All settings are environment variables. For `agentic-workflow.sh`, stage keys are
the log names: `REQUIREMENTS`, `PROJECT_PLAN`, `ADVERSARIAL_REVIEW`,
`UPDATED_PLAN`, `IMPLEMENTATION`, `MANUAL_CHECKLIST`, `EXECUTE_CHECKLIST`,
`FINAL_AUDIT`.

| Variable | Default | Effect |
|---|---|---|
| `WORKFLOW_SPECULATE` | `1` | Run the next stage during a gate |
| `WORKFLOW_AGENT_CMD` | `claude` | Primary agent CLI or wrapper |
| `WORKFLOW_REVIEWER_CMD` | `codex` | Reviewer CLI or wrapper |
| `WORKFLOW_MODEL_<STAGE>` | `opus`; `sonnet` for requirements and checklist execution | Model for one stage |
| `WORKFLOW_EFFORT_<STAGE>` | `high`; `medium` for those two | Reasoning effort |
| `WORKFLOW_TURNS_<STAGE>` | `40`; `200` implementation, `120` checklist execution | Turn cap |
| `WORKFLOW_TOOLS_<STAGE>` | `Read,Glob,Grep,Write` (+ `Edit,TodoWrite,Bash` for implementation and checklist execution) | Tool allowlist |
| `CODEX_MODEL` | Codex default | Model for all reviewer stages |

Example:

```sh
WORKFLOW_MODEL_REQUIREMENTS=opus WORKFLOW_TURNS_IMPLEMENTATION=300 \
  ./scripts/agentic-workflow.sh
```

Use a different primary agent or reviewer by setting the command variables:

```sh
WORKFLOW_AGENT_CMD=kimi WORKFLOW_REVIEWER_CMD=codex \
  ./scripts/agentic-workflow.sh
```

The swapped CLI must accept the same flags the driver passes. If the flags
 differ, provide a wrapper script that translates them and set the variable to
that wrapper's path.

`change-workflow.sh` has additional knobs for tracks, per-stage dollar budgets,
and parallel checklist generation. Defaults and documentation are in the
header of `scripts/change-workflow.sh`.

## State and logs

Everything under `.workflow/` is gitignored:

```
.workflow/state              current stage
.workflow/approvals/*.sha256 recorded approvals
.workflow/logs/*.jsonl       raw primary-agent event streams
.workflow/logs/*.log         reviewer transcripts, speculative stage output
.workflow/speculative/       input hashes for speculative stages (agentic-workflow.sh)
.workflow/cost.tsv           per-stage spend ledger (change-workflow.sh)
.workflow/change.diff        authoritative diff the final audit reads (change-workflow.sh)
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

## Contributing

- Read [`QUICK_START.md`](QUICK_START.md) to run the workflows end-to-end.
- Read [`AGENTIC.md`](AGENTIC.md) to understand the design philosophy.
- Read [`GOOD_FIRST_ISSUES.md`](GOOD_FIRST_ISSUES.md) for small, well-scoped
  starter tasks.
- Read [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) before participating.
- Read [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full contributor guide.
- Open an issue to discuss larger changes before spending time on them.

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
