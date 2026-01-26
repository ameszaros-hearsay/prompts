# Unit Testing Reference Examples

This file contains complete, detailed examples of well-structured test suites following the GUTs methodology.

## Table of Contents

- [Leap Year Example (Complete)](#leap-year-example-complete)
- [Queue Example (Complete)](#queue-example-complete)
- [Common Test Smells and Fixes](#common-test-smells-and-fixes)
- [Minimal Correct Implementation Checks](#minimal-correct-implementation-checks)

---

## Leap Year Example (Complete)

### Domain Rules

- A year divisible by 4 but not by 100 is a leap year
- A year divisible by 400 is a leap year
- All other years are not leap years
- Only positive years are supported

### Complete Test Suite

```pseudo
SUITE "leap_year_spec"

  GROUP "a_year_is_a_leap_year_if"
    TEST "divisible_by_4_but_not_by_100"
      FOR_EACH year IN [2024, 2028, 2016, 2020, 2012]
        ASSERT is_leap_year(year) == true

    TEST "divisible_by_400"
      FOR_EACH year IN [2000, 2400, 2800, 1600]
        ASSERT is_leap_year(year) == true

  GROUP "a_year_is_not_a_leap_year_if"
    TEST "not_divisible_by_4"
      FOR_EACH year IN [2023, 2022, 1999, 3, 2019, 2017]
        ASSERT is_leap_year(year) == false

    TEST "divisible_by_100_but_not_by_400"
      FOR_EACH year IN [1900, 2100, 2200, 2300, 1800]
        ASSERT is_leap_year(year) == false

  GROUP "a_year_is_supported_if"
    TEST "positive"
      FOR_EACH year IN [1, 4, 100, 400, MAX_INT]
        ASSERT_NOTHROW { is_leap_year(year) }

  GROUP "a_year_is_not_supported_if"
    TEST "zero"
      ASSERT_THROWS IllegalArgumentException { is_leap_year(0) }

    TEST "negative"
      FOR_EACH year IN [-1, -400, MIN_INT]
        ASSERT_THROWS IllegalArgumentException { is_leap_year(year) }
```

### Coverage Analysis

**Common cases:** Years around today (2020-2028) - mix of leap and non-leap
**Simple cases:** Very small numbers (1, 3, 4) that clearly illustrate rules
**Boundary cases:**

- 100 (divisible by 4 and 100, but not 400)
- 400 (divisible by 4, 100, and 400)
- MIN_INT, MAX_INT (extreme boundaries)
  **Error cases:** Zero and negative years

---

## Queue Example (Complete)

### Domain Model

States:

- `empty` - length = 0
- `non_empty` - length > 0
    - `non_full` - length < capacity
    - `full` - length = capacity

### Complete Test Suite

```pseudo
SUITE "queue_spec"

  GROUP "creating_a_queue"
    TEST "leaves_it_empty"
      queue = Queue(capacity: 10)
      ASSERT queue.length() == 0

    TEST "preserves_positive_bounding_capacity"
      FOR_EACH cap IN [1, 5, 10, 100, MAX_INT]
        queue = Queue(capacity: cap)
        ASSERT queue.capacity() == cap

    TEST "fails_with_non_positive_bounding_capacity"
      FOR_EACH cap IN [0, -1, -10, MIN_INT]
        ASSERT_THROWS IllegalArgumentException { Queue(capacity: cap) }

  GROUP "given_empty_queue"
    SETUP
      queue = Queue(capacity: 3)

    TEST "when_enqueuing_then_length_increases"
      queue.enqueue("item1")
      ASSERT queue.length() == 1

      queue.enqueue("item2")
      ASSERT queue.length() == 2

    TEST "when_dequeuing_then_returns_nothing_and_stays_empty"
      result = queue.dequeue()
      ASSERT result == null
      ASSERT queue.length() == 0

  GROUP "given_non_empty_non_full_queue"
    SETUP
      queue = Queue(capacity: 5)
      queue.enqueue("first")
      queue.enqueue("second")

    TEST "when_enqueuing_then_length_increases_and_order_is_fifo"
      queue.enqueue("third")
      ASSERT queue.length() == 3
      ASSERT queue.peek() == "first"

    TEST "when_dequeuing_then_length_decreases_and_returns_oldest"
      result = queue.dequeue()
      ASSERT result == "first"
      ASSERT queue.length() == 1
      ASSERT queue.peek() == "second"

  GROUP "given_full_queue"
    SETUP
      queue = Queue(capacity: 2)
      queue.enqueue("first")
      queue.enqueue("second")

    TEST "when_enqueuing_then_is_ignored_or_reports_full_without_error"
      result = queue.enqueue("third")
      ASSERT result == false  # or returns status
      ASSERT queue.length() == 2

    TEST "when_dequeuing_then_becomes_non_full"
      queue.dequeue()
      ASSERT queue.length() == 1
      result = queue.enqueue("new")
      ASSERT result == true
      ASSERT queue.length() == 2
```

### State Transition Coverage

- `empty` → `non_empty` via enqueue
- `non_empty_non_full` → `full` via enqueue
- `full` → `full` via enqueue (rejected)
- `full` → `non_empty_non_full` via dequeue
- `non_empty` → `empty` via dequeue(s)
- `empty` → `empty` via dequeue (no-op)

---

## Common Test Smells and Fixes

### Smell: Monolithic Test Method

**Bad:**

```pseudo
TEST "test"
  queue = Queue(10)
  ASSERT queue.length() == 0
  queue.enqueue("a")
  ASSERT queue.length() == 1
  queue.enqueue("b")
  ASSERT queue.peek() == "a"
  result = queue.dequeue()
  ASSERT result == "a"
  ASSERT queue.length() == 1
  # ... 50 more lines
```

**Good:**
Split into focused tests with clear names (see Queue example above).

---

### Smell: Arbitrary File Scattering

**Bad:**

```
tests/
  test_enqueue.py
  test_dequeue.py
  test_peek.py
  test_length.py
  test_capacity.py
```

**Good:**

```
tests/
  queue_spec.py  # Contains all queue behavior grouped by state
```

---

### Smell: Numbers in Names Without Meaning

**Bad:**

```pseudo
TEST "test_2000_is_leap"
TEST "test_1900_is_not_leap"
TEST "test_2024_is_leap"
```

**Good:**

```pseudo
TEST "a_year_divisible_by_400_is_a_leap_year"
  FOR_EACH year IN [2000, 2400, 2800]
    ASSERT is_leap_year(year) == true
```

---

### Smell: Contradictory Names

**Bad:**

```pseudo
TEST "valid_years_are_processed"
  ASSERT is_leap_year(0) == false  # but 0 should throw!

TEST "only_positive_years_are_valid"
  ASSERT is_leap_year(-1) throws exception
```

These contradict each other - is 0 valid or not?

**Good:**

```pseudo
TEST "a_year_is_supported_if_positive"
  FOR_EACH year IN [1, 4, 100, 400, MAX_INT]
    ASSERT_NOTHROW { is_leap_year(year) }

TEST "a_year_is_not_supported_if_zero_or_negative"
  FOR_EACH year IN [0, -1, -400, MIN_INT]
    ASSERT_THROWS { is_leap_year(year) }
```

---

### Smell: Verbose Boilerplate

**Bad:**

```pseudo
TEST "test_that_a_year_divisible_by_4_but_not_by_100_is_a_leap_year"
TEST "test_that_a_year_divisible_by_400_is_a_leap_year"
TEST "test_that_a_year_not_divisible_by_4_is_not_a_leap_year"
```

**Good:**
Use nesting to eliminate "test*that*" and "a_year":

```pseudo
SUITE "leap_year_spec"
  GROUP "a_year_is_a_leap_year_if"
    TEST "divisible_by_4_but_not_by_100"
    TEST "divisible_by_400"
```

---

## Minimal Correct Implementation Checks

### Principle

A trivial wrong implementation should fail a targeted test with a meaningful message.

### Example: Julian Calendar Rule (Wrong)

```pseudo
FUNCTION is_leap_year(year):
  RETURN year % 4 == 0
```

This implements the Julian calendar rule, not Gregorian.

### Expected Failing Test

```pseudo
TEST "a_year_divisible_by_100_but_not_by_400_is_not_a_leap_year"
  FOR_EACH year IN [1900, 2100, 2200]
    ASSERT is_leap_year(year) == false
```

**Expected failure message:**

```
AssertionError: Expected is_leap_year(1900) to be false, but was true
```

The test name directly reveals what rule is missing: the 100-divisibility exception.

### Counter-Example: Bad Test Name

```pseudo
TEST "test_boundary_values"
  ASSERT is_leap_year(1900) == false
```

**Failure message:**

```
AssertionError: Expected false, got true
```

This failure tells you almost nothing. You have to look at the code to understand what rule failed.

---

## State-Centric Testing Pattern

Use when your domain naturally models as states and transitions.

### Pattern Template

```pseudo
SUITE "<entity>_spec"

  # Constructor/factory tests
  GROUP "creating_<entity>"
    TEST "establishes_initial_state"
    TEST "validates_required_parameters"
    TEST "fails_with_invalid_parameters"

  # Tests grouped by starting state
  GROUP "given_<state_A>"
    SETUP
      # Establish state A

    # Tests grouped by operation
    GROUP "when_<operation_1>"
      TEST "then_<result_1>"
      TEST "then_<result_2>"

    GROUP "when_<operation_2>"
      TEST "then_<result_3>"

  GROUP "given_<state_B>"
    # ... similar structure
```

### When to Use

- State transitions are core to domain (queues, state machines, workflows)
- Multiple operations available in each state
- Operations have different effects depending on current state
- Need to verify state invariants after operations

### When NOT to Use

- Pure functions with no state
- Simple validators or calculators
- Stateless transformations
- Single-operation classes

For these, prefer simpler grouping:

```pseudo
SUITE "leap_year_spec"
  GROUP "a_year_is_a_leap_year_if"
    TEST "<condition>"
  GROUP "a_year_is_not_a_leap_year_if"
    TEST "<condition>"
```
