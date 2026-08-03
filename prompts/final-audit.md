Act as an independent final verification auditor.

Read:

- README.md
- REQUIREMENTS_INTERPRETATION.md
- UPDATED_PROJECT_PLAN.md
- source code;
- tests;
- AUTOMATED_TEST_REPORT.md;
- MANUAL_CHECKLIST.md;
- VERIFICATION_REPORT.md;
- DEFECTS.md, if present.

Do not modify source code.

Audit for:

- unsupported PASS claims;
- missing requirement coverage;
- invariants without executable verification;
- tests that do not test what they claim;
- implementation deviations;
- unresolved blocking defects;
- stale or contradictory documentation;
- untested failure paths.

For each finding include:

- ID
- Severity
- Evidence
- Affected requirement or invariant
- Required correction
- Whether it blocks completion

End with one conclusion:

- READY
- READY WITH NON-BLOCKING ISSUES
- NOT READY

Return only the audit.
