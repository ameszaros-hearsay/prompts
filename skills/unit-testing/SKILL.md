---
name: unit-testing
description: Generic unit test best practices based on Good Unit Tests (GUTs) methodology. Use when writing or reviewing unit tests in any language/framework to ensure tests are clear specifications of behavior with propositional names, proper grouping, parameterization, and comprehensive case coverage.
---

# Unit Testing Best Practices

Good Unit Tests (GUTs) are specifications of behavior, not just correctness checks. Follow these principles in any language or framework.

## Core Objectives

- **Communicate intent** - Tests explain what the production code does and why
- **Isolate ideas** - Each test covers one logical idea
- **Fail usefully** - A failing test tells you exactly what is wrong
- **Workflow agnostic** - Applies whether you use TDD or not

## Guiding Principles

1. **Write for people** - Primary audience is future readers trying to understand production code
2. **Use propositional names** - Test names are true or false statements
3. **Avoid contradictions** - Test names within a suite must be mutually consistent
4. **Structure the narrative** - Order and group tests to teach the domain
5. **Separate three layers**: Intention (specification sentence), Example code (act/asserts), Example data (values, parameterized)
6. **Prefer parameterized tests** - Modern frameworks support data-driven tests
7. **Cover meaningful cases** - Common, simple, boundary, and error cases
8. **Never trust an unseen failure** - See the test fail at least once

## Naming Standard

Use sentences that are either true or false. Prefer domain terms over test mechanics.

**Examples:**

- `a_year_not_divisible_by_4_is_not_a_leap_year`
- `a_year_divisible_by_4_but_not_by_100_is_a_leap_year`
- `a_year_divisible_by_100_but_not_by_400_is_not_a_leap_year`
- `a_year_divisible_by_400_is_a_leap_year`

**Display helpers:** If your framework supports display-name generators, replace underscores with spaces in reports.

## Organizing with Nesting

Group by domain concepts. Start broad, then refine.

**Leap year outline:**

- `leap_year_spec`
    - `a_year_is_a_leap_year_if`
        - `divisible_by_4_but_not_by_100`
        - `divisible_by_400`
    - `a_year_is_not_a_leap_year_if`
        - `not_divisible_by_4`
        - `divisible_by_100_but_not_by_400`
    - `a_year_is_supported_if` / `a_year_is_not_supported_if`

This hierarchy communicates the model and removes repeated wording.

## Given–When–Then

Use Given, When, Then both inside tests and for grouping:

- **Given** sections define shared state groups
- **When** sections define shared action groups
- **Then** sections are individual truth statements

**Example grouping:**

- Given a queue in state S
    - When operation O
        - Then result R

Pick the structure that best communicates the domain.

## Parameterization

Keep the statement of truth fixed, feed multiple representative values.

```pseudo
TEST "a_year_not_divisible_by_4_is_not_a_leap_year"
FOR_EACH year IN [2023, 2022, 1999, 3]
ASSERT is_leap_year(year) == false
```

**Guidelines:**

- Use domain-looking values, not `1, 2, 3` or `foo`
- Expand sets cheaply by adding rows, not copying tests

## Coverage Matrix

Ensure representatives of:

- **Common** cases (typical inputs)
- **Simple** cases (small, obvious numbers)
- **Boundary** cases (divisibility edges, min/max)
- **Error** cases (unsupported inputs, illegal states)

## Error & Support Constraints

Explicitly test supported domain boundaries. Emphasize notable debates as separate tests.

```pseudo
TEST "a_year_is_not_supported_if_zero"
  ASSERT_THROWS IllegalArgumentException { is_leap_year(0) }

TEST "a_year_is_supported_if_positive"
  FOR_EACH year IN [1, 4, 100, 400, MAX_INT]
    ASSERT_NOTHROW { is_leap_year(year) }
```

## Quick Reference

### Do

- Write statements of truth
- Group by domain concept
- Parameterize examples
- Cover common, simple, boundary, error
- Make failures diagnostic

### Do Not

- Use `test_1`, `should_work`, or `works_as_expected`
- Scatter by API method name alone
- Copy paste near-duplicate tests
- Hide domain rules inside numbers
- Accept unreadable test reports

## Review Checklist

Run on every PR:

- [ ] Names are statements that can be true or false
- [ ] Each test expresses one logical idea
- [ ] The suite reads like a specification from top to bottom
- [ ] Common, simple, boundary, and error cases are represented
- [ ] Parameterization used where multiple examples illustrate the same statement
- [ ] Failing output would pinpoint the missing rule
- [ ] No contradictions among test names
- [ ] Notable domain debates surfaced as separate tests
- [ ] Unsupported inputs and supported domain boundaries are explicit
- [ ] Display names in reports are readable by humans

## Templates

### Propositional Test

```pseudo
SUITE "<subject>_spec"
  GROUP "<broad_truth_condition>"
    TEST "<propositional_statement>"
      // Arrange
      // Act
      // Assert
```

### Parameterized Test

```pseudo
TEST "<propositional_statement>"
  FOR_EACH <row> IN <table_of_examples>
    // Arrange with <row>
    // Act
    // Assert expected outcome for <row>
```

### State-Centric Test

```pseudo
SUITE "<subject>_spec"
  GROUP "given_<state_A>"
    GROUP "when_<operation_X>"
      TEST "then_<result_R1>"
      TEST "then_<result_R2>"
  GROUP "given_<state_B>"
    ...
```

## Migration Strategy

For existing codebases:

1. Identify top suites run most often or changed most recently
2. Rename tests to propositional statements without changing bodies
3. Introduce nesting to remove repeated phrases
4. Convert duplicate tests with different values to parameterized tests
5. Add explicit error and support-boundary tests
6. Reorder suites from most common cases to least common
7. Enforce the checklist in code review

## Language Support

Works with JUnit, NUnit, pytest, Jest, and similar. Prefer parameterized features:

- JUnit: `@ParameterizedTest`
- NUnit: `TestCaseSource`
- pytest: `@pytest.mark.parametrize`
- Jest: `test.each`

Use display-name features to render underscores as spaces if available.

---

For complete examples and detailed patterns, see [REFERENCE.md](REFERENCE.md).
