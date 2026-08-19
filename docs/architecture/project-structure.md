# Project structure

The layout follows ADR-002: domain logic in a pure Swift package so its tests run on macOS in
milliseconds, adapters in a second package, and the app target reduced to views, view models
and wiring.

```
food-map/
├── docs/                              Specifications — the source of truth
│   ├── README.md                      Index and reading order
│   ├── workflow.md                    docs → test cases → test code → code
│   ├── traceability.md                story → use case → requirement → test → code
│   ├── requirements/
│   │   ├── srs.md                     Software Requirements Specification
│   │   ├── user-stories.md            The originating stories
│   │   └── use-cases.md               UC-1 … UC-6 with all flows
│   ├── architecture/
│   │   ├── adr-001-map-and-search.md  Map provider, with Vietnam measurements
│   │   ├── adr-002-architecture-and-testing.md
│   │   ├── adr-003-ui-design.md       Visual language (pending decision)
│   │   └── project-structure.md       This file
│   └── testing/
│       └── test-cases.md              TC-1-01 … TC-X-06
│
├── Packages/
│   ├── FoodMapDomain/                 Pure Swift. No Apple frameworks. Tests run on macOS.
│   │   ├── Sources/FoodMapDomain/
│   │   │   ├── Entities/              Place, Meal, Photo, Coordinate — plain structs
│   │   │   ├── Ports/                 Protocols the domain needs satisfied
│   │   │   ├── UseCases/              One type per user intention
│   │   │   └── Services/              Pure logic: clustering, matching, formatting
│   │   └── Tests/FoodMapDomainTests/
│   │       ├── Fakes/                 In-memory doubles + Vietnamese fixtures
│   │       ├── UseCases/              Named after their TC- ids
│   │       └── Services/
│   │
│   └── FoodMapData/                   Adapters implementing the domain's ports
│       ├── Sources/FoodMapData/
│       │   ├── Persistence/           SwiftData models + mappers
│       │   ├── Photos/                File system storage, ImageIO EXIF reading
│       │   ├── Search/                Apple Maps adapter
│       │   └── Location/              Core Location adapter
│       └── Tests/FoodMapDataTests/
│           └── Fixtures/              Real JPEGs, incl. southern-hemisphere GPS
│
├── FoodMap/                           The iOS app target
│   ├── FoodMapApp.swift               Entry point
│   ├── Composition/                   The only place that knows every concrete type
│   ├── Features/                      One folder per screen: view + @Observable model
│   │   ├── Map/
│   │   ├── AddMeal/
│   │   ├── PlaceDetail/
│   │   ├── SavePlace/
│   │   └── NearMe/
│   └── DesignSystem/                  Colours, typography, reusable components
│
├── FoodMapUITests/                    XCUITest journeys, stubbed search and GPS
├── project.yml                        xcodegen spec — the .xcodeproj is generated
└── README.md
```

## Rules that keep the structure honest

1. **Dependencies point inward.** `FoodMapDomain` imports nothing. `FoodMapData` imports the
   domain. The app imports both. Nothing ever points outward.
2. **No business rule lives in a view.** If a `View` contains an `if` about what the product
   *means*, it belongs in a use case.
3. **One use case type per user intention**, named for the intention: `LogMealUseCase`, not
   `MealManager`.
4. **Adapters are named for what they adapt to** — `AppleMapsPlaceSearchAdapter` — so swapping
   the provider is an obvious, contained change.
5. **The `.xcodeproj` is generated, never hand-edited.** Run `xcodegen generate`; the spec in
   `project.yml` is what is reviewed and committed.
6. **Test files are named after the test cases they implement**, so a failing test names the
   specification it violates.

## Commands

| Task | Command |
|---|---|
| Fast domain test loop | `swift test --package-path Packages/FoodMapDomain` |
| Adapter tests | `swift test --package-path Packages/FoodMapData` |
| Regenerate the Xcode project | `xcodegen generate` |
| Build the app | `xcodebuild -scheme FoodMap -destination 'platform=iOS Simulator,name=iPhone 17'` |
| End-to-end journeys | `xcodebuild test -scheme FoodMap -destination '…' -only-testing:FoodMapUITests` |
