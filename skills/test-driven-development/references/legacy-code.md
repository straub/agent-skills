# TDD with Legacy Code

Working with legacy code—code without tests—is one of the most common real-world TDD scenarios. The challenge is that you can't apply pure TDD (write test first) without destabilizing existing functionality. This guide covers proven techniques for adding tests and making changes safely.

## Guiding Principles

**Don't retrofit TDD to everything.** Legacy code is often too tightly coupled to test effectively. Instead:
- Test what you change
- Write characterization tests for the current behavior
- Extract new logic into testable units
- Use refactoring techniques that preserve behavior while creating seams

## For New Code in Legacy Systems

When adding new features or components to a legacy system:

### Approach: Full TDD in New Units

Apply pure TDD to any new code:
- New services, utilities, or components
- New endpoints or handlers
- New business logic layers

**Benefit**: Your new code is well-tested and decoupled from legacy code. It serves as an island of quality.

### The Strangler Fig Pattern

Gradually replace legacy code by growing tested code around it:

1. **Identify** the legacy code that needs improvement
2. **Extract or create** new, testable units that provide the same behavior
3. **Wire the new code** into the system, calling the legacy code or replacing it incrementally
4. **Gradually shift** responsibility from legacy to new code
5. **Remove** legacy code once fully replaced

**Example**: A monolithic `OrderProcessor` class that does everything.
- Extract a new `OrderValidator` service (write tests first)
- Extract a new `PricingCalculator` service (write tests first)
- Have `OrderProcessor` delegate to these services
- Over time, replace more of `OrderProcessor`

## For Modifying Legacy Code (The Characterization Test Workflow)

When you must change existing untested code, follow this process:

### Step 1: Capture Current Behavior (Characterization Tests)

Write tests that document *current behavior*, whether or not it seems correct.

**Why**: You need a baseline to ensure your changes don't break anything unexpectedly.

```python
# This test documents current behavior, even if it's odd
def test_discount_calculator_with_zero_items():
    # Current system returns 100, not 0
    assert discount_calculator.calculate([]) == 100
```

**How to write characterization tests**:
1. Call the function/method with sample inputs
2. Observe the actual output
3. Write an assertion for that output
4. Run the test—it should pass (documenting current behavior)

### Step 2: Find Untested Code Paths

Use code coverage tools to identify which branches and paths your tests don't exercise.

```bash
# Python example
coverage run -m pytest tests/
coverage report -m
# Shows which lines aren't covered
```

**Focus your characterization tests** on untested paths to establish a safety net.

### Step 3: Make Your Change Using TDD

Now that current behavior is characterized, make your change using TDD:

1. Write a failing test for the *new* behavior you want
2. Make it pass with minimal code
3. Run all tests (old characterization + new behavior tests)
4. Refactor if safe

**Key**: The characterization tests prevent regression while your new test drives the change.

```python
# Characterization test (documents current broken behavior)
def test_discount_with_empty_list():
    assert discount_calculator.calculate([]) == 100  # Old behavior

# New test (drives the fix)
def test_discount_with_empty_list_should_be_zero():
    assert discount_calculator.calculate([]) == 0  # New behavior

# Both tests: characterization prevents breaking other behavior,
# new test drives the fix
```

### Step 4: Run the Full Suite

Ensure your change doesn't break anything else. The characterization tests are your safety net.

---

## Key Techniques for Legacy Code

### Technique 1: Seams

A "seam" is a place where you can alter behavior without editing production code directly.

#### Seams via Dependency Injection

```python
# Hard to test: dependency is internal
class OrderProcessor:
    def process(self):
        payment_gateway = PaymentGateway()  # Can't swap this
        ...

# Easy to test: dependency is injected
class OrderProcessor:
    def __init__(self, payment_gateway):
        self.payment_gateway = payment_gateway
    
    def process(self):
        ...
```

#### Seams via Method Extraction

```python
# Original: tightly coupled
def calculate_total(cart):
    items = fetch_items_from_database()  # Coupled to DB
    return sum(item.price for item in items)

# Refactored: seam created
def calculate_total(cart):
    items = self.fetch_items(cart)
    return sum(item.price for item in items)

def fetch_items(self, cart):
    return fetch_items_from_database()

# Now you can override fetch_items in a test subclass
# or inject a different implementation
```

### Technique 2: Golden Master (Approval Testing)

For complex code where behavior is hard to specify precisely:

1. **Run the legacy code** with various inputs
2. **Capture the output** (the "golden master")
3. **Commit that output** as the characterization test baseline
4. **Detect changes**: If the output differs from the master, tests fail

This works especially well for:
- Complex transformations (parsing, rendering)
- Systems with many edge cases
- Code where correctness is "what it currently does"

**Tool example**: ApprovalTests library

```python
def test_complex_report_generation():
    result = legacy_report_generator.generate_report(data)
    verify(result)  # Compares against approved output
```

### Technique 3: Sprout Method/Class

Extract new logic into a separate, testable unit:

```python
# Original: logic buried in legacy code
def process_order(order):
    # ... lots of legacy code ...
    if order.amount > 100:
        discount = order.amount * 0.1
    else:
        discount = 0
    # ... more legacy code ...
    return final_amount - discount

# Refactored: extract the discount logic
def calculate_discount(amount):
    return amount * 0.1 if amount > 100 else 0

def process_order(order):
    # ... lots of legacy code ...
    discount = calculate_discount(order.amount)  # Now testable!
    # ... more legacy code ...
    return final_amount - discount
```

Now `calculate_discount` can be tested independently with TDD.

---

## When You're Completely Stuck

If the code is:
- Tightly coupled with databases, external APIs, file systems
- Impossible to instantiate without a complex setup
- Deeply embedded in framework magic

### Option 1: Write Approval Tests

Capture current behavior as approval tests, then refactor to create testable seams.

### Option 2: Integration Tests

Test the legacy code end-to-end:
- Set up a test database
- Mock external APIs
- Use fixtures and factories

Integration tests are slower but provide safety for legacy code. Unit tests can come later as you extract units.

### Option 3: Document and Schedule Refactoring

If adding tests is genuinely impossible, document *why* and schedule a dedicated refactoring effort. Don't leave code untested indefinitely.

---

## Quick Checklist: Adding Tests to Legacy Code

- [ ] Is this new code or changes to existing code?
- [ ] If new: Apply full TDD immediately
- [ ] If changes: Write characterization tests first
- [ ] Can I inject dependencies to create seams? (Do so)
- [ ] Are there obvious "sprout" methods I can extract and test?
- [ ] Have I run a coverage report to find untested paths?
- [ ] Do characterization tests document current behavior?
- [ ] Do new tests drive the intended change?
- [ ] Do all tests (old + new) pass?

