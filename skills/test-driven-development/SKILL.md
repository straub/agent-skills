---
name: test-driven-development
description: Test-Driven Development specialist enforcing write-tests-first methodology. Use PROACTIVELY when writing new features, fixing bugs, or refactoring code. Ensures code quality through Red-Green-Refactor cycles. Apply this skill by default for any code changes - don't wait to be asked.
---

# Test-Driven Development Skill

**Use this skill PROACTIVELY** - Apply TDD to all code changes by default. Tests come first, implementation follows.

## Core Philosophy

TDD is about **design**, **confidence**, and **rapid feedback**. Write tests first to guide better interfaces and simpler implementations. The goal: **"Clean code that works"** — Ron Jeffries

---

## The Red-Green-Refactor Cycle

This is your core workflow - use it for every code change:

### Step 1: RED - Write a Failing Test

Write ONE test that describes the behavior you want:

```typescript
describe('calculateDiscount', () => {
  it('applies 10% discount when total exceeds $100', () => {
    const total = calculateDiscount(150)
    expect(total).toBe(135)
  })
})
```

**Run the test** - It MUST fail. This proves you're testing something real.

### Step 2: GREEN - Make It Pass

Write the **minimum code** to make the test pass:

```typescript
function calculateDiscount(amount: number): number {
  if (amount > 100) {
    return amount * 0.9
  }
  return amount
}
```

**Run the test** - It should now pass. Don't add extra features or perfect the code yet.

### Step 3: REFACTOR - Clean Up

Improve the code while keeping all tests green:
- Remove duplication
- Improve naming
- Simplify logic
- Extract functions

**Run tests after each change** - They must stay green.

### Step 4: REPEAT

Pick the next test and start over. Small steps, frequent validation.

---

## When to Use TDD (ALWAYS)

Apply TDD proactively to:

✅ **New features** - Start with a test describing desired behavior
✅ **Bug fixes** - Write a failing test that reproduces the bug, then fix it  
✅ **Refactoring** - Tests ensure behavior doesn't change
✅ **API endpoints** - Test request/response contracts
✅ **Business logic** - Test calculations, validations, transformations
✅ **Any code change** - Default to TDD unless truly impossible

Skip only for:
- Trivial config changes
- Pure exploratory spikes (throw away the code after)
- Generated code (test the generator or output, not both)

---

## Test Types to Write

### Unit Tests (Mandatory)
Test individual functions in isolation:

```typescript
describe('validateEmail', () => {
  it('returns true for valid email', () => {
    expect(validateEmail('user@example.com')).toBe(true)
  })

  it('returns false for missing @', () => {
    expect(validateEmail('userexample.com')).toBe(false)
  })

  it('handles null gracefully', () => {
    expect(validateEmail(null)).toBe(false)
  })
})
```

### Integration Tests (For APIs & Database)
Test components working together:

```typescript
describe('POST /api/users', () => {
  it('creates user and returns 201', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ email: 'test@example.com' })

    expect(response.status).toBe(201)
    expect(response.body.email).toBe('test@example.com')
  })

  it('returns 400 for invalid email', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ email: 'invalid' })

    expect(response.status).toBe(400)
  })
})
```

---

## Edge Cases to Test

Always test these scenarios:

1. **Null/Undefined** - What if input is null?
2. **Empty** - Empty array, empty string, zero
3. **Invalid Types** - Wrong type passed in
4. **Boundaries** - Min/max values, limits
5. **Errors** - Network failures, database errors
6. **Special Characters** - Unicode, SQL injection attempts

---

## Mocking External Dependencies

Mock at system boundaries to keep tests fast and reliable:

### Mock APIs
```typescript
jest.mock('@/lib/api-client', () => ({
  fetchUser: jest.fn(() => Promise.resolve({
    id: 1,
    email: 'test@example.com'
  }))
}))
```

### Mock Database
```typescript
jest.mock('@/lib/database', () => ({
  query: jest.fn(() => Promise.resolve([
    { id: 1, name: 'Test User' }
  ]))
}))
```

**Don't over-mock**: Only mock external dependencies (APIs, databases, file system). Let real code run when possible.

---

## Common Mistakes to Avoid

❌ **Skipping the RED step** - Always see the test fail first  
❌ **Writing too much code** - Only write enough to pass the current test  
❌ **Skipping refactoring** - Clean up continuously, don't accumulate debt  
❌ **Testing implementation** - Test behavior/outputs, not internal details  
❌ **Over-mocking** - Mock only external dependencies, not everything

---

## TDD Workflow Checklist

### Before Starting
- [ ] Understand the behavior I'm implementing
- [ ] Test environment is set up and running
- [ ] Ready to see RED first

### Each Cycle (Repeat)
1. [ ] Write ONE test describing desired behavior
2. [ ] Run test - verify it FAILS (RED)
3. [ ] Write minimum code to make it pass
4. [ ] Run test - verify it PASSES (GREEN)  
5. [ ] Refactor code while keeping tests green
6. [ ] Run all tests - verify nothing broke

### Before Committing
- [ ] All tests passing
- [ ] Code is clean and readable
- [ ] No unnecessary code added

---

## Quick Reference

```
RED → GREEN → REFACTOR → REPEAT

RED:      Write test. Watch it FAIL.
GREEN:    Write minimum code to PASS.
REFACTOR: Clean up. Keep tests GREEN.
```

**Remember**: Tests first, always. No production code without a failing test driving it.