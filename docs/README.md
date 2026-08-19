# Food Map — documentation

A private iPhone app for remembering the food you have eaten and the places you still want to
try, both on a map. No account, no server; photos stay on the device.

## Reading order

| # | Document | Answers |
|---|---|---|
| 1 | [requirements/user-stories.md](requirements/user-stories.md) | What did the user actually ask for? |
| 2 | [requirements/srs.md](requirements/srs.md) | What must the product do, and how well? |
| 3 | [requirements/use-cases.md](requirements/use-cases.md) | How does a user achieve each goal, including when things go wrong? |
| 4 | [architecture/adr-001-map-and-search.md](architecture/adr-001-map-and-search.md) | Which map, which search, and does it work in Vietnam? |
| 5 | [architecture/adr-002-architecture-and-testing.md](architecture/adr-002-architecture-and-testing.md) | How is the code layered and how is it tested? |
| 6 | [architecture/project-structure.md](architecture/project-structure.md) | Where does each file go? |
| 7 | [testing/test-cases.md](testing/test-cases.md) | What exactly is verified? |
| 8 | [workflow.md](workflow.md) | In what order is anything allowed to be built? |
| 9 | [traceability.md](traceability.md) | Which test proves which requirement? |

## The rule

```
docs → test cases → test code → implementation
```

Nothing is implemented before the step above it exists and is agreed. If implementation shows
the specification was wrong, the document is corrected first — never left to drift.

## Status

| Area | State |
|---|---|
| User stories | 3 captured |
| Use cases | UC-1 … UC-6 written |
| SRS | draft v0.1, 2 open questions (OPEN-2, OPEN-3) |
| Test cases | 51 specified (39 unit, 7 integration, 5 e2e) — all automated |
| Domain code | **complete and green** — 52 tests, sub-second warm loop, no simulator |
| Test totals | 84 automated, all passing — 52 unit, 25 integration, 7 e2e journeys |
| UI/UX | decided — travel-journal/editorial, ADR-003 |
| Data adapters | **complete and green** — SwiftData, file system, ImageIO, Apple Maps |
| App target | **built and running** — 6 screens, verified in the simulator, light and dark |
| E2E tests | **complete and green** — 7 XCUITest journeys covering all 5 cases, run against stubbed adapters |
