# Implementation Strategies

When a test is failing and you need to make it pass, you have three fundamental strategies to choose from. None is universally "best"—pick based on your current confidence and complexity level.

## Strategy 1: Obvious Implementation

When the solution is clear and straightforward, implement it directly.

### When to Use
- The solution is obvious to you
- You have high confidence
- The code is simple and unlikely to surprise you
- You're in a familiar domain or pattern

### Example

**Test:**
```python
def test_add():
    assert add(2, 3) == 5
```

**Obvious Implementation:**
```python
def add(a, b):
    return a + b
```

### Strengths
- Fast
- Efficient
- Zero waste

### Risks
- Can miss nuance if the problem is more complex than it appears
- Might write more than needed if you're not careful

---

## Strategy 2: Fake It ('Til You Make It)

Return a hardcoded value that makes the test pass, then generalize only when forced by the next test.

### When to Use
- You're unsure of the approach
- The implementation feels complex or risky
- You want to stay in "green" longer and build incrementally
- You're exploring an unfamiliar domain

### Example

**Test 1:**
```python
def test_filter_greater_than_one():
    assert filter([1, 2, 3], lambda x: x > 1) == [2, 3]
```

**Fake It (Pass Test 1):**
```python
def filter(items, predicate):
    return [2, 3]  # Hardcoded!
```

**Test 2:**
```python
def test_filter_all():
    assert filter([1, 2, 3], lambda x: True) == [1, 2, 3]
```

**Generalize (Pass Test 2):**
```python
def filter(items, predicate):
    result = []
    for item in items:
        if predicate(item):
            result.append(item)
    return result
```

### Strengths
- Keeps you in green (safer feeling)
- Forces you to write more tests to drive actual logic
- Prevents over-engineering
- Great for exploration

### Risks
- Can feel wasteful if taken to extremes
- Temptation to leave hardcoded values
- Might mask when you don't actually understand the problem

### Best Practice
Use Fake It deliberately, not accidentally. When you hardcode a value, acknowledge it: "I'm faking this until the next test forces me to generalize." Then immediately write the next test.

---

## Strategy 3: Triangulation

Write multiple tests that represent different cases, then write code that satisfies all of them simultaneously.

### When to Use
- You're not sure how to proceed
- The algorithm or pattern isn't obvious
- You need multiple examples to see the generalization
- You're working on a complex calculation or transformation

### Example

**Test 1:**
```python
def test_discount_under_threshold():
    assert calculate_discount(50) == 0
```

**Code (Pass Test 1):**
```python
def calculate_discount(amount):
    return 0
```

**Test 2:**
```python
def test_discount_at_threshold():
    assert calculate_discount(100) == 5
```

**Code (Pass Test 2):**
```python
def calculate_discount(amount):
    if amount >= 100:
        return 5
    return 0
```

**Test 3:**
```python
def test_discount_high_amount():
    assert calculate_discount(200) == 20
```

**Code (Triangulate - Pass All):**
```python
def calculate_discount(amount):
    return int(amount * 0.1) if amount >= 100 else 0
```

Now you've triangulated to the actual formula.

### Strengths
- Clarifies the pattern through multiple examples
- Prevents premature abstractions
- Great for discovering algorithms
- Forces you to understand the domain

### Risks
- Can feel slow if you write too many test cases upfront
- Temptation to write all tests before any code (violating TDD)
- Overkill for simple cases

---

## Shifting Between Strategies

You don't commit to one strategy for an entire feature. **Shift strategies based on feedback**:

```
Obvious Implementation
    ↓ [Hit unexpected red bar?]
    ↓ [Algorithm isn't clear?]
    ↓
Fake It ('Til You Make It)
    ↓ [Confidence returning?]
    ↓ [Pattern becoming clear?]
    ↓
Triangulation or Obvious Implementation
```

### Example Workflow

1. **Start with Obvious Implementation** for a simple calculation.
2. **Hit a red bar** you didn't expect. The case is more complex.
3. **Switch to Fake It** to gain safety and understanding.
4. **Add multiple tests** to triangulate to the real pattern.
5. **Return to Obvious Implementation** now that the pattern is clear.

This flexibility is what makes TDD powerful. You're not locked into a plan; you adapt based on reality.

---

## Anti-Patterns to Avoid

### Obvious Implementation Overreach
Writing "obvious" code that's actually complex and fragile.

**Fix**: If your "obvious" code has edge cases or complexity, downshift to Fake It.

### Excessive Faking
Hardcoding values for 10+ tests without triangulating to real logic.

**Fix**: Write one or two tests, fake, then immediately write the next test. Use triangulation to drive generalization.

### Premature Triangulation
Writing 10 test cases before any code, trying to predict all cases upfront.

**Fix**: Write one test, make it pass, then decide if you need triangulation or can shift to Obvious Implementation.

