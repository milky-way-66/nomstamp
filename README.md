# Food Map

A private iPhone app for remembering the food you have eaten and the places you still want to
try — both on a map. Photograph a dish where you eat it and the photo becomes the pin.

**No account. No server. Photos never leave the device.**

## Status

Domain and data layers complete and fully tested — **74 tests, all green, no simulator
required**. The app UI is next.

```
swift test --package-path Packages/FoodMapDomain     # 51 tests, ~0.8s
swift test --package-path Packages/FoodMapData       # 23 tests, ~0.1s
RUN_NETWORK_TESTS=1 swift test --package-path Packages/FoodMapData   # + 2 live Apple Maps tests
```

## Documentation

Start at [`docs/README.md`](docs/README.md). The build order is strict:

```
docs → test cases → test code → implementation
```

| Document | Purpose |
|---|---|
| [SRS](docs/requirements/srs.md) | What the product must do, and how well |
| [Use cases](docs/requirements/use-cases.md) | How users achieve each goal, including failures |
| [ADR-001](docs/architecture/adr-001-map-and-search.md) | Map provider, with measured Vietnam coverage |
| [ADR-002](docs/architecture/adr-002-architecture-and-testing.md) | Clean architecture and test strategy |
| [ADR-003](docs/architecture/adr-003-ui-design.md) | Visual design language |
| [Test cases](docs/testing/test-cases.md) | The 55 cases that verify it |
| [Traceability](docs/traceability.md) | Which test proves which requirement |

## Structure

```
Packages/FoodMapDomain/   Pure Swift. No Apple frameworks. Tests run on macOS.
Packages/FoodMapData/     Adapters: SwiftData, file system, Apple Maps.
FoodMap/                  SwiftUI app: views, view models, composition.   (next)
```
