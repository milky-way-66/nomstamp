# Test Cases

Step 2 of `workflow.md`. Every flow in `use-cases.md` gets at least one case here; every case
here gets an automated test named after its ID.

**Levels:** `U` unit (domain, fakes, macOS) · `I` integration (real SwiftData / file system /
ImageIO) · `E` end-to-end (XCUITest, stubbed search + GPS + camera).

Status: `spec` = specified, not yet automated · `auto` = an automated test exists and passes.

**As of 2026-08-19:** every case at all three levels is automated and green — 39 unit and 7
integration cases implemented by 77 test functions (the extras are edge cases found while
writing them), and the 5 e2e cases implemented by 7 XCUITest journeys in `FoodMapUITests`.
The e2e journeys run against stubbed search, location, photo and storage adapters selected by
the `-UITestMode` launch argument, so they need no network, no GPS and no camera.

The two live-network tests are opt-in and skipped by default, so the suite is deterministic
offline (NFR-7.5). Run them deliberately with `RUN_NETWORK_TESTS=1 swift test`.

---

## UC-1 — Log a meal with a photo

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-1-01 | U | main | Given a photo and a chosen nearby place, when the meal is logged, then a meal exists with 1 photo, the clock's time, and that place | **auto** |
| TC-1-02 | U | main | Given a brand-new place, when the first meal is logged there, then the place reports kind `visited` | **auto** |
| TC-1-03 | U | E1 | Given location permission is denied, when the user picks a place by search and logs a meal, then the meal saves successfully | **auto** |
| TC-1-04 | U | 1a | Given a gallery photo carrying EXIF GPS and capture time, when logged, then `eatenAt` is the EXIF time — **not** now — and the suggested coordinate is the EXIF one | **auto** |
| TC-1-05 | U | 1a | Given a photo with no EXIF, when logged, then `eatenAt` is the injected clock's now and the coordinate is the current fix | **auto** |
| TC-1-06 | U | 4b | Given an existing wishlist place, when a meal is logged against it, then no second place is created and the place becomes `visited` | **auto** |
| TC-1-07 | U | 4a | Given the place is not in search results, when the user supplies a coordinate and types a name, then a place is created at exactly that coordinate | **auto** |
| TC-1-08 | U | E2 | Given photo storage throws, when logging, then the use case returns a failure and **no partial meal is persisted** | **auto** |
| TC-1-09 | U | main | Given a meal with 3 photos, when logged, then all 3 are attached in the order supplied | **auto** |
| TC-1-10 | U | 6a | Given the search port throws (no network), when the user logs a meal with a manual name and GPS, then the meal still saves | **auto** |
| TC-1-11 | I | main | Given a real JPEG, when stored, then a full image and a thumbnail exist on disk and both decode | **auto** |
| TC-1-12 | I | 1a | Given a JPEG with southern/western hemisphere GPS, when metadata is read, then latitude and longitude are correctly **negated** | **auto** |
| TC-1-13 | I | 1a | Given a JPEG with no GPS block, when metadata is read, then coordinate is nil and no error is thrown | **auto** |
| TC-1-14 | E | main | Given an empty app, when the user adds a meal from the fixture photo, then a pin appears on the map | **auto** |
| TC-1-16 | U | 3 | Given a saved place 40 m from the meal's coordinate and another 900 m away, when the place is suggested, then the near one is chosen as an **existing** place, so no duplicate pin is created | **auto** |
| TC-1-17 | U | 3 | Given no saved place nearby but two search candidates, when the place is suggested, then the nearer candidate is chosen as a **new** place draft, and a candidate beyond 120 m is never chosen | **auto** |
| TC-1-18 | U | E1, 6a | Given no coordinate, or a search port that throws, when the place is suggested, then the result is nil and no error escapes | **auto** |
| TC-1-19 | E | main | Given an empty app, when the user taps `+`, takes a photo, taps a star and saves, then the meal is stored with that score and the place was never chosen by hand | **auto** |
| TC-1-15 | U | FR-1.4 | Given a photo carrying EXIF time, when the user sets the time by hand, then the typed time wins over both the EXIF and the clock | **auto** |

> TC-1-08 is the one worth writing first. Saving a meal touches disk *and* the database; a
> naive implementation leaves an orphaned meal row when the photo write fails.

---

## UC-2 — Browse my food map

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-2-01 | U | main | Given places inside and outside the visible bounds, when pins are requested, then only those inside are returned | **auto** |
| TC-2-02 | U | 3a | Given 2 meals at one restaurant, when pins are built, then there is exactly **1** pin reporting a meal count of 2 | **auto** |
| TC-2-03 | U | main | Given one visited and one wishlist place, when pins are built, then their kinds differ | **auto** |
| TC-2-04 | U | step 4 | Given 2 places 10 m apart at city zoom, when clustered, then they collapse into 1 cluster of 2 | **auto** |
| TC-2-05 | U | step 4 | Given the same 2 places at street zoom, when clustered, then they are 2 separate clusters | **auto** |
| TC-2-06 | U | step 4 | Given a cluster containing exactly 1 place, then its coordinate equals that place's coordinate exactly (no averaging drift) | **auto** |
| TC-2-07 | U | 3a | Given a place with 2 meals, when the pin thumbnail is chosen, then it is the **most recent** meal's first photo | **auto** |
| TC-2-08 | U | 5a | Given a visited and a wishlist place, when filtering by `wishlist`, then only the wishlist place is returned | **auto** |
| TC-2-09 | U | step 4 | Given 200 places in one city, when clustered, then the cluster count stays far below 200 and every place appears in exactly one cluster | **auto** |
| TC-2-10 | E | 1a | Given no places, when the map opens, then the empty state and its two actions are shown | **auto** |

> TC-2-09's real assertion is **conservation**: no place may be dropped or duplicated by
> clustering. That is the bug clustering code actually has.

---

## UC-3 — Open a place and see its meals

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-3-01 | U | step 2 | Given 3 meals on different dates, when the place is opened, then they are ordered newest first | **auto** |
| TC-3-02 | U | 2a | Given a wishlist place, when opened, then it has no meals and its saved note is returned | **auto** |
| TC-3-03 | U | step 3 | Given a meal is deleted, when the place is reloaded, then the meal is gone and other meals survive | **auto** |
| TC-3-04 | I | step 3 | Given a meal with photos is deleted, then its image **files are removed from disk**, not just the rows | **auto** |
| TC-3-05 | I | step 3 | Given a place is deleted, then its meals and all their photo files are removed | **auto** |
| TC-3-07 | E | step 1 / FR-4.6 | Given a place opened from the list, then the map is still visible above the sheet — the place does not cover it — and going back returns the sheet to its peek | **auto** |
| TC-3-06 | I | step 3 / FR-4.5 | Given a place, when directions are requested, then a map item is produced carrying that place's name and exact coordinate | **auto** |

> TC-3-04 and TC-3-05 guard a leak that a database-only test cannot see: cascade delete
> removes rows, but the JPEGs would sit on the user's device forever.

---

## UC-4 — Save a place I heard about

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-4-01 | U | main | Given a search result, when saved with a note, then a place of kind `wishlist` exists carrying that note | **auto** |
| TC-4-02 | U | 3a | Given a saved place with provider id `X`, when the same result is saved again, then the existing place is returned and the total count stays 1 | **auto** |
| TC-4-03 | U | 3a | Given a manually saved place with no provider id, when a place of the same name 30 m away is saved, then it is treated as the same place | **auto** |
| TC-4-04 | U | 3a | Given the same, when a place of the same name **300 m** away is saved, then a new place is created | **auto** |
| TC-4-05 | U | 3a | Given a saved place whose name differs only by diacritics/case (`pho thin` vs `Phở Thìn`) at the same spot, then it is treated as the same place | **auto** |
| TC-4-06 | U | 2a | Given the place cannot be found by search, when the user drops a pin and types a name, then a wishlist place is created there | **auto** |
| TC-4-07 | U | step 4 | Given tags are supplied, when saved, then they are persisted and searchable | **auto** |
| TC-4-08 | I | — | Given the Apple search adapter, when asked for nearby food places, then it uses a **category filter and never a free-text category word** (network-tagged, excluded by default) | **auto** |
| TC-4-09 | E | main | Given the user searches a name and saves it, then a wishlist pin appears and its note shows when opened | **auto** |

> TC-4-05 is Vietnam-specific and easy to get wrong: users type without diacritics, so
> `pho thin` and `Phở Thìn` must compare equal.
> TC-4-08 encodes the ADR-001 finding — free-text `"cà phê"` returned a result 1,100 km away,
> so the adapter must never take that path.

---

## UC-5 — Find saved places near me while travelling

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-5-01 | U | main | Given saved places at 100 m, 2 km and 50 km, when searching within 5 km, then the first two are returned, **nearest first** | **auto** |
| TC-5-02 | U | main | Given the same, then the 50 km place is excluded | **auto** |
| TC-5-03 | U | 2a | Given saved places only in Hanoi and the user is in HCMC, when searching nearby, then the result is **empty and successful** — not an error | **auto** |
| TC-5-04 | U | — | Given no location fix is available, then the outcome is a distinct `locationUnavailable` case, distinguishable from "nothing nearby" | **auto** |
| TC-5-05 | U | main | Given both visited and wishlist places nearby, then both are returned (travelling users want their old favourites too) | **auto** |
| TC-5-06 | E | main+2a | Given a seeded city, then a place is listed with its distance; given an empty city, then the explicit "nothing saved near here" message is shown | **auto** |

> TC-5-03 vs TC-5-04 is the distinction that makes this feature trustworthy: "you saved
> nothing here" and "I don't know where you are" must never look the same to the user.

---

## UC-6 — Mark a wishlist place as visited

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-6-01 | U | step 3 | Given a wishlist place, when a meal is logged there, then its kind becomes `visited` | **auto** |
| TC-6-02 | U | step 3 | Given that place had the note "Lan said try the pho", after the transition the note is **still present** | **auto** |
| TC-6-03 | U | step 3 | Given the transition happened, then the place id is unchanged — it was converted, not replaced | **auto** |
| TC-6-04 | U | step 3 | Given a visited place, when its only meal is deleted, then it reverts to `wishlist` rather than disappearing | **auto** |
| TC-6-05 | E | main | Given a wishlist pin, when the user taps "I ate here" and logs a meal, then the pin renders as visited and the note survives | **auto** |

> TC-6-04 is a flow the use-case document does not mention — deleting the last meal. Because
> `kind` is derived, reverting is automatic, but the behaviour should be pinned by a test so a
> later refactor to a stored flag cannot silently break it. **`use-cases.md` should be updated
> to state this**, per the "docs first" rule in `workflow.md`.

---

## UC-7 — Rate a meal

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-7-01 | U | main | Given a meal logged with a score of 4, then the stored meal carries that rating | **auto** |
| TC-7-02 | U | 1a | Given a meal rated 3, when it is rated 5, then the meal reads 5 and nothing else about it changes | **auto** |
| TC-7-03 | U | 1b | Given a meal rated 4, when the same score is applied again, then the rating is cleared | **auto** |
| TC-7-04 | U | E1 | Given a meal rated 3, when a score of 0 or 6 is applied, then it is rejected and the meal still reads 3 | **auto** |
| TC-7-05 | U | main | Given meals rated 5, 4 and unrated, then the place's average is 4.5 | **auto** |
| TC-7-06 | E | 1a | Given a logged meal, when its stars are tapped on the place screen, then the new rating shows without leaving the screen | **auto** |

---

## Cross-cutting

| ID | Lvl | Concern | Given → When → Then | Status |
|---|---|---|---|---|
| TC-X-01 | U | Clock | Given a fixed clock at 2026-01-01, when a meal is logged with no EXIF, then `eatenAt` is exactly that instant | **auto** |
| TC-X-02 | U | Mapper | Given a domain place, when mapped to persistence and back, then it is unchanged | **auto** |
| TC-X-03 | U | Mapper | Given a meal with photos, when round-tripped, then photo order and metadata survive | **auto** |
| TC-X-04 | I | Persistence | Given an in-memory container, when a place with meals and photos is saved and refetched, then the whole graph is intact | **auto** |
| TC-X-05 | U | Formatting | Given 850 m → "850 m"; given 2,400 m → "2.4 km" | **auto** |
| TC-X-06 | U | Distance | Given two known Hanoi coordinates, then the computed distance matches the known value within 1% | **auto** |

---

## Non-functional cases

The FR-driven cases above say the app does the right thing; these say it does it fast enough,
in the user's language, durably, legibly and privately. They were added on 2026-08-19 after an
audit found 28 of the 31 SRS non-functional requirements had no case at all.

| ID | Lvl | Traces | Given → When → Then | Status |
|---|---|---|---|---|
| TC-N-01 | E | NFR-5.1, NFR-5.2 | Given the device language is Vietnamese, when the app launches, then the interface is Vietnamese, not English | **auto** |
| TC-N-02 | I | NFR-3.1 | Given a place with a meal and photo written to an on-disk store, when the store is closed and reopened, then the whole graph is still there | **auto** |
| TC-N-03 | U | NFR-2.2 | Given 500 saved places, when the map pin pipeline runs, then it completes inside one 60 fps frame budget (16 ms) | **auto** |
| TC-N-04 | U | NFR-2.2 | Given 5,000 saved places, when clustering runs, then it stays well inside a quarter second and still conserves every place | **auto** |
| TC-N-05 | I | NFR-2.3 | Given one full-size photograph, when a meal is saved, then storing image, thumbnail and record takes ≤ 1 s | **auto** |
| TC-N-06 | E | NFR-2.1 | Given a cold start, when the app launches, then an interactive map is reached in ≤ 2 s | **auto** |
| TC-N-07 | U | NFR-6.4 | Given every foreground/background pair in the palette, then each meets its WCAG AA contrast minimum, in both light and dark | **auto** |
| TC-N-08 | U | NFR-1.1, NFR-1.2, NFR-1.3 | Given the shipped source, then it declares no third-party dependency and makes no network call outside the place-search adapter | **auto** |
| TC-N-09 | I | NFR-3.3, FR-1.8 | Given a photo directory that cannot be written, when a meal is saved, then the error surfaces, nothing partial is stored, and nothing crashes | **auto** |
| TC-N-10 | E | NFR-6.1 | Given the largest accessibility text size, when the map opens, then the primary actions are still present and hittable | **auto** |
| TC-N-11 | E | NFR-6.2 | Given the map screen, then every control carries a VoiceOver label, not a bare image name | **auto** |

Two requirements stay deliberately unautomated: **NFR-2.2's frame rate itself** (a unit test can
bound the work per frame, as TC-N-03 does, but only a device measurement can prove 55 fps), and
**NFR-4.1's tap count**, which is a design review, not an assertion. Both are recorded here so
the omission is visible rather than forgotten.

---

## Coverage check against `use-cases.md`

| Use case | Flows specified | Flows with a test case |
|---|---|---|
| UC-1 | main, 1a, 4a, 4b, 6a, E1, E2 | all |
| UC-7 | main, 1a, 1b, E1 | all |
| UC-2 | main, 1a, 3a, 5a | all |
| UC-3 | main, 2a | all |
| UC-4 | main, 2a, 3a | all |
| UC-5 | main, 2a | all |
| UC-6 | main | all, plus the undocumented delete-last-meal case (TC-6-04) |

**Total: 79 test cases** — 56 unit, 11 integration, 12 e2e. The shape is deliberate: the pyramid
is widest where it is cheapest and fastest to run.

| | Specified | Automated | Passing | Implemented by |
|---|---|---|---|---|
| Unit | 56 | 56 | 56 | 70 test functions (`FoodMapDomain` 68, `FoodMapDesign` 2) |
| Integration | 11 | 11 | 11 | 28 test functions (`FoodMapData`) |
| E2E | 12 | 12 | 12 | 15 XCUITest journeys (`FoodMapUITests`) |
