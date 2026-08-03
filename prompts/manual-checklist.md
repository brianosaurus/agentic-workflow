Act as an independent release-verification engineer.

Inspect:

- README.md
- REQUIREMENTS_INTERPRETATION.md
- PROJECT_PLAN.md
- ADVERSARIAL_REVIEW.md
- UPDATED_PROJECT_PLAN.md
- IMPLEMENTATION_NOTES.md, if present
- AUTOMATED_TEST_REPORT.md
- all source code and tests

Do not modify source code.
Do not claim that any check passed.

Create MANUAL_CHECKLIST.md.

For every check include:

- Check ID
- Priority
- Related requirement
- Related behavior
- Related invariant
- Prerequisites
- Exact action
- Expected result
- Evidence to capture
- Actual result: blank
- Status: NOT RUN

Include sections for:

1. Smoke checks
2. User-visible behaviors
3. Domain invariants
4. Boundary conditions
5. Invalid input
6. Failure paths
7. Full-stack integration
8. Restart and recovery
9. Requirements not covered by automated tests
10. Regression checks

End with a traceability matrix.

Return only the checklist.
