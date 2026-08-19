# Working agreement — how a feature gets built

Nothing is implemented until the step above it exists and is agreed.

```
1. DOCS        user story  →  use case (main / alternate / exception flows)
                     ↓
2. TEST CASES  a numbered, human-readable case per flow, with expected results
                     ↓
3. TEST CODE   an automated test per test case, named after its ID — and failing
                     ↓
4. CODE        the minimum implementation that turns those tests green
```

## Traceability
Every artifact carries the ID of its parent, so any line of code can be traced back to the
user story that justifies it, and any story can be traced forward to the tests proving it.

```
US-1  →  UC-1  →  TC-1-03  →  test_TC_1_03_locationDenied_fallsBackToSearch()  →  LogMealUseCase
```

Rules:
- A use case flow with no test case is an **incomplete specification**.
- A test case with no automated test is a **gap**, and is listed as such rather than quietly dropped.
- Implementation code that no test case covers is **unjustified** — either a test case was
  missed in the docs, or the code is not needed.

## Step 3 in practice (TDD)
1. Write the test for one test case. Run it. **Confirm it fails for the expected reason** —
   a test that passes before the feature exists is testing nothing.
2. Write the least code that makes it pass.
3. Refactor with the test green.
4. Move to the next test case.

## Levels
| Level | Runs on | Speed | Covers |
|---|---|---|---|
| Unit | macOS via `swift test` | milliseconds | Domain use cases and pure logic, against fakes |
| Integration | macOS (mostly) / simulator | ~seconds | Real SwiftData, real file system, real EXIF decoding |
| E2E | iOS simulator, XCUITest | ~minutes | Whole user journeys with stubbed search, GPS and camera |

## Changing a decision
If implementation reveals the spec was wrong, the fix goes **back to the document first**,
then the test case, then the test, then the code. The docs never become stale by drift.
