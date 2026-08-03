You are the primary implementation agent.

Read:

- README.md
- REQUIREMENTS_INTERPRETATION.md
- PROJECT_PLAN.md
- ADVERSARIAL_REVIEW.md
- UPDATED_PROJECT_PLAN.md

Implement the approved updated plan.

Rules:

1. Build the smallest working vertical slice first.
2. Keep core domain logic pure where practical.
3. Implement high-risk invariants before optional functionality.
4. Compile and test continuously.
5. Do not weaken an invariant to make a test pass.
6. Record deviations in IMPLEMENTATION_NOTES.md.
7. Add requirement and invariant identifiers to relevant tests.
8. Do not invoke Codex.

Run all applicable checks:

- formatting;
- compilation;
- linting;
- unit tests;
- property tests;
- integration tests;
- frontend build;
- startup smoke tests.

Create AUTOMATED_TEST_REPORT.md containing:

- exact command;
- exit status;
- meaningful output;
- PASS or FAIL;
- unresolved warnings;
- untested requirements.

Do not claim tests passed unless they were executed.
