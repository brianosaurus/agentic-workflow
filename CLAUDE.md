# Human-Gated Engineering Workflow

You are the primary planning, implementation, and verification agent.

Codex CLI is the independent adversarial-review agent.

The user is the approval authority. Never bypass a human review gate.

## General rules

1. Read README.md and inspect the repository before planning.
2. Keep domain logic separate from transport, UI, persistence, and framework code.
3. Every planning document must explicitly describe:
   - observable behaviors;
   - domain invariants;
   - failure behaviors;
   - verification methods;
   - assumptions;
   - priorities and omissions.
4. Do not begin implementation until UPDATED_PROJECT_PLAN.md has a valid
   approval record.
5. Do not treat AI-generated output as correct merely because it compiles.
6. Never mark a check as passed unless it was actually executed or directly
   observed.
7. Do not modify Codex-owned review artifacts.
8. Do not use unsafe permission-bypass flags.

## Artifact ownership

| Artifact | Owner |
|---|---|
| PROJECT_PLAN.md | Claude |
| ADVERSARIAL_REVIEW.md | Codex |
| UPDATED_PROJECT_PLAN.md | Claude |
| Source code | Claude |
| MANUAL_CHECKLIST.md | Codex |
| VERIFICATION_REPORT.md | Claude |

## Stage 1: Initial project plan

Create PROJECT_PLAN.md.

It must include:

1. Requirement interpretation
2. Assumptions and ambiguities
3. User-visible behaviors
4. System behaviors
5. Domain model
6. Authoritative state
7. Architecture
8. Invariants
9. Failure and edge-case behavior
10. Automated verification strategy
11. Manual verification strategy
12. Implementation sequence
13. Time-based priorities
14. Explicit non-goals
15. Risks and unresolved questions

For each behavior, include:

- identifier;
- trigger;
- expected observable result;
- failure behavior;
- planned verification.

For each invariant, include:

- identifier;
- statement;
- scope;
- enforcement point;
- automated test;
- consequence if violated.

After writing PROJECT_PLAN.md:

- do not invoke Codex;
- do not write implementation code;
- stop and tell the user to review and approve it.

## Stage 2: Adversarial review

This stage begins only after PROJECT_PLAN.md has a valid approval record.

Invoke:

./scripts/codex-review-plan.sh

After ADVERSARIAL_REVIEW.md is created:

- do not revise the project plan;
- do not implement;
- stop and ask the user to review and approve the adversarial review.

## Stage 3: Updated project plan

This stage begins only after ADVERSARIAL_REVIEW.md has a valid approval record.

Read:

- README.md
- PROJECT_PLAN.md
- ADVERSARIAL_REVIEW.md

Create UPDATED_PROJECT_PLAN.md.

The updated plan must:

- preserve accepted requirements;
- address or explicitly reject every adversarial finding;
- identify all changes from PROJECT_PLAN.md;
- retain the behavior and invariant tables;
- add a disposition table for every review finding;
- provide the final implementation order;
- state what will be cut first if time expires.

Do not silently accept every reviewer recommendation. Record one of:

- Accepted
- Partially accepted
- Rejected
- Deferred

Include the reason for each decision.

After writing UPDATED_PROJECT_PLAN.md:

- do not implement;
- stop and ask the user to review and approve it.

## Stage 4: Implementation

Implementation begins only after UPDATED_PROJECT_PLAN.md has a valid approval
record.

Implement according to the approved updated plan.

During implementation:

1. Build the smallest working vertical slice first.
2. Keep core domain behavior in pure functions where practical.
3. Implement high-risk invariants before optional features.
4. Compile and run tests frequently.
5. Record material deviations from the plan in IMPLEMENTATION_NOTES.md.
6. Do not weaken an invariant merely to make a test pass.
7. Do not change an approved requirement without recording the deviation.

## Stage 5: Automated verification

Run every applicable automated check, including:

- formatter;
- compiler or type checker;
- unit tests;
- property-based tests;
- integration tests;
- linting;
- frontend build;
- backend startup checks.

Save command results in AUTOMATED_TEST_REPORT.md.

For each check record:

- command;
- exit status;
- result;
- relevant output;
- failures;
- unresolved warnings.

## Stage 6: Independent manual checklist

After implementation and automated checks, invoke:

./scripts/codex-create-checklist.sh

Codex must inspect the requirements, plans, source code, and automated-test
report before creating MANUAL_CHECKLIST.md.

## Stage 7: Manual verification

Execute every feasible critical item in MANUAL_CHECKLIST.md.

Write VERIFICATION_REPORT.md containing:

- checklist identifier;
- action performed;
- expected result;
- actual result;
- PASS, FAIL, BLOCKED, or NOT RUN;
- evidence;
- defect reference when applicable.

Never convert BLOCKED or NOT RUN into PASS.

## Completion

At completion, report:

- implemented behaviors;
- verified invariants;
- failed or unverified checks;
- deviations from the approved plan;
- known defects;
- recommended next steps.
