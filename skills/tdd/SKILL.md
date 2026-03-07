---
name: tdd
description: Test-driven development with red-green-refactor loop. Use when user wants to build features or fix bugs using TDD, mentions "red-green-refactor", wants integration tests, or asks for test-first development.
---

# Test-Driven Development

Build features using vertical-slice TDD: one test, one implementation, repeat. Tests verify behavior through public interfaces — not implementation details.

## Instructions

### Step 1: Plan the interface

Before writing any code:

- [ ] Confirm with user what interface changes are needed
- [ ] Confirm which behaviors to test (you can't test everything — prioritize)
- [ ] Design interfaces for testability — see [references/interface-design.md](references/interface-design.md)
- [ ] Look for opportunities to create deep modules — see [references/deep-modules.md](references/deep-modules.md)
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors are most important to test?"

### Step 2: Write the tracer bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior -> test fails
GREEN: Write minimal code to pass -> test passes
```

This proves the path works end-to-end.

### Step 3: Incremental loop

For each remaining behavior:

```
RED:   Write next test -> fails
GREEN: Minimal code to pass -> passes
```

Rules:
- One test at a time. Never write all tests first then all implementation (horizontal slicing produces crap tests)
- Only enough code to pass the current test
- Don't anticipate future tests
- Keep tests focused on observable behavior

### Step 4: Refactor

After all tests pass, look for refactor candidates — see [references/refactoring.md](references/refactoring.md):

- [ ] Extract duplication
- [ ] Deepen modules (move complexity behind simple interfaces)
- [ ] Apply SOLID principles where natural
- [ ] Consider what new code reveals about existing code
- [ ] Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

## Checklist per cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```

## Additional resources

- For good vs bad test examples, see [references/tests.md](references/tests.md)
- For mocking guidelines (system boundaries only), see [references/mocking.md](references/mocking.md)
- For deep module design patterns, see [references/deep-modules.md](references/deep-modules.md)
- For interface design principles, see [references/interface-design.md](references/interface-design.md)
- For refactor candidates after TDD cycle, see [references/refactoring.md](references/refactoring.md)
