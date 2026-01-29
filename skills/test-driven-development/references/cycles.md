# TDD Cycles

TDD operates at multiple time scales, each with its own rhythm and purpose. Understanding these cycles helps maintain both immediate discipline and long-term architectural integrity.

## Nano-Cycle (Seconds): The Three Laws

The finest grain of TDD discipline, enforced line-by-line:

1. **You must write a failing test before you write any production code.**
2. **You must not write more of a test than is sufficient to fail** (or fail to compile).
3. **You must not write more production code than is sufficient to make the currently failing test pass.**

These laws enforce the rhythm that prevents scope creep and keeps you in deep flow. The nano-cycle is where the magic happens—each decision is small, reversible, and validated immediately.

## Micro-Cycle (Minutes): Red-Green-Refactor

The fundamental rhythm of TDD:

1. **Red**: Write one test. Watch it fail (proving the test works).
2. **Green**: Write minimum code to make it pass. No architecture, no optimization—just pass.
3. **Refactor**: Clean up without changing behavior. Remove duplication, improve names, extract methods.

The entire cycle typically takes 2–10 minutes. Refactoring happens *continuously* throughout this cycle, not deferred to the end. Each micro-cycle completes one test from your test list.

### Micro-Cycle Anti-Patterns

- **Skipping red**: Never skip seeing the test fail. It proves the test actually tests something.
- **Writing too much test**: Keep each test focused on one behavior.
- **Writing too much code**: Resist the urge to "just add" the next feature. Let the next test drive it.
- **Skipping refactoring**: Continuous refactoring prevents code rot. It's not optional.

## Milli-Cycle (10 Minutes): Specific/Generic

As you write more tests, code naturally becomes more generic. This cycle is about **test order mattering**:

The pattern: *As tests get more specific, code gets more generic.*

### Recognizing Flow vs. Stuck

**On track**: You can imagine tests you haven't written that would already pass with your current code.

Example: You wrote a test for `filter([1, 2, 3], x > 1)` returning `[2, 3]`. Your code generalizes to any predicate. A test for `filter(['a', 'b'], x == 'a')` would already pass.

**Getting stuck**: Each new test requires large changes to the implementation. This means your test order is suboptimal.

Example: You wrote `filter([1, 2, 3], x > 1)` using a hardcoded list size. Now adding a test for different sizes requires rewriting everything.

### Fixing Test Order

If you hit a wall:
1. **Pause and backtrack**—don't force the next test to pass
2. **Choose a different test** from your list that builds incrementally
3. **Resume from green**—revert to the last passing state
4. **Try again** with better sequencing

Test order is a crucial skill. Poor test order makes TDD feel tedious; good test order makes it feel effortless. This is something to actively cultivate.

## Primary Cycle (Hourly): Architecture Check

Every hour (or at significant decision points), step back and verify you're not crossing architectural boundaries.

### Questions to Ask

- Have I stayed within the component/module I set out to work on?
- Are my tests revealing an unexpected design issue?
- Should I refactor at a larger scale (extract a class, split a module)?
- Do my test names still reflect the intended behavior, or have I drifted?

This cycle is less rigid than the others. It's a checkpoint to ensure local TDD discipline isn't creating global problems. Sometimes you'll discover you should restructure significantly—that's valuable feedback from your tests.

### Architectural Signals

If tests become hard to write:
- New dependencies are leaking in
- A class is taking too many responsibilities
- Public interfaces are too granular or too coarse
- You need to mock too many dependencies

These are hints to refactor at the architecture level, not the code level.

---

## Choosing Your Test Order (Milli-Cycle Strategy)

Experienced TDD practitioners spend as much thought on test order as on the test content itself.

### Strategy 1: Happy Path First
Start with the simplest success case, then add edge cases.

**Pros**: Quick to green, feels productive.
**Cons**: Can lead to poor abstractions if not followed carefully.

### Strategy 2: Simplest Variant First
Start with a boundary case that forces minimal logic.

Example: Testing a sort function, start with empty list, then single item, then two items, then duplicates.

**Pros**: Builds code incrementally from simple to complex.
**Cons**: Requires more thought upfront.

### Strategy 3: Error Cases First
Start with what should fail.

**Pros**: Clarifies requirements early.
**Cons**: Code can feel over-engineered early on.

Most practitioners mix strategies, starting with happy path but watching for the "stuck" signal, then reordering as needed.

