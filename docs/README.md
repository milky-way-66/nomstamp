# Nomstamp — documentation

A private iPhone app for remembering the food you have eaten and the places you still want to
try, both on a map. No server of ours, nothing to pay for. Photos stay on the device, except the
thumbnails of places you deliberately share with a friend you met in person — and those travel
sealed, readable by that friend and by nobody else.

## Reading order

| # | Document | Answers |
|---|---|---|
| 1 | [requirements/user-stories.md](requirements/user-stories.md) | What did the user actually ask for? |
| 2 | [requirements/srs.md](requirements/srs.md) | What must the product do, and how well? |
| 3 | [requirements/use-cases.md](requirements/use-cases.md) | How does a user achieve each goal, including when things go wrong? |
| 4 | [architecture/adr-001-map-and-search.md](architecture/adr-001-map-and-search.md) | Which map, which search, and does it work in Vietnam? |
| 5 | [architecture/adr-002-architecture-and-testing.md](architecture/adr-002-architecture-and-testing.md) | How is the code layered and how is it tested? |
| 6 | [architecture/adr-003-ui-design.md](architecture/adr-003-ui-design.md) | What does it look like, and why that? |
| 7 | [architecture/adr-004-location.md](architecture/adr-004-location.md) | Which position do we trust, and when? |
| 8 | [architecture/adr-005-art-direction.md](architecture/adr-005-art-direction.md) | How does it stop looking like stock SwiftUI? |
| 9 | [architecture/adr-006-skins-and-weather.md](architecture/adr-006-skins-and-weather.md) | Why does it change colour, and what decides? |
| 9c | [architecture/adr-008-friends.md](architecture/adr-008-friends.md) | *(superseded)* Why a peer-to-peer mesh, and why it was revisited |
| 9c′ | [architecture/adr-009-friends-shared-zone.md](architecture/adr-009-friends-shared-zone.md) | How do a friend's stamps reach my map without a server of ours? |
| 9d | [architecture/research-friend-sync.md](architecture/research-friend-sync.md) | Which transports were considered, and why this one? |
| 9e | [architecture/adr-011-camera.md](architecture/adr-011-camera.md) | Why is the viewfinder more than a shutter, and where is the front camera? |
| 9f | [design/voice-2026-08-21.md](design/voice-2026-08-21.md) | How does the app sound, and what does it call things — in both languages? |
| 10 | [architecture/project-structure.md](architecture/project-structure.md) | Where does each file go? |
| 11 | [testing/test-cases.md](testing/test-cases.md) | What exactly is verified? |
| 12 | [workflow.md](workflow.md) | In what order is anything allowed to be built? |
| 13 | [traceability.md](traceability.md) | Which test proves which requirement? |
| 11 | [deployment/testflight.md](deployment/testflight.md) | How does a build reach TestFlight, and then the store? |

## The rule

```
docs → test cases → test code → implementation
```

Nothing is implemented before the step above it exists and is agreed. If implementation shows
the specification was wrong, the document is corrected first — never left to drift.

## Status

| Area | State |
|---|---|
| User stories | 4 captured |
| Use cases | UC-1 … UC-6 written |
| SRS | draft v0.1, 2 open questions (OPEN-2, OPEN-3) |
| Test cases | 148 specified (116 unit, 16 integration, 16 e2e) — 146 automated; 2 await two devices or a live iCloud account |
| Domain code | **complete and green** — 125 tests, sub-second warm loop, no simulator. Includes the whole friends domain: redaction, manifest diff, matching, the cap and the ink |
| Test totals | 273 automated, all passing — 145 domain, 24 design, 72 data, 32 e2e journeys |
| UI/UX | decided — travel-journal/editorial, ADR-003; palette now enforced by TC-N-07 |
| Friends | **built and green, mid-redesign** — ADR-009 for the transport and ceremony; **ADR-010 amends what the map draws**: a friend's place is drawn exactly as the reader's own, their wishlist travels too, provenance moves to the place page, and the filter gains a kind. Documents are corrected; the domain and interface are **not yet changed**. The radio path still has no field evidence — TC-8-12 and OPEN-13 are owed |
| Localisation | **Vietnamese and English**, String Catalog, verified by TC-N-01. **Voice pass applied** (voice note 21 Aug, NFR-4.5 … NFR-4.7, NFR-5.5): 158 keys → 155, ten synonyms retired, errors given actions, the Vietnamese rewritten off the English, and the three `xanh` inks separated. Two strings had no catalogue entry at all and shipped untranslated. The four copy lints (TC-N-30 … TC-N-33) are **still owed** |
| Camera | **built** — ADR-011, two passes: front camera, lens discovery for macro, 0.5x/1x/2x marks, zoom, tap-to-focus, exposure drag and AE/AF lock, torch that surfaces rather than fires, volume-button shutter, a viewfinder that holds several dishes, a flat-lay mark, orientation from `RotationCoordinator`, shutter haptic and dim, and a capture that stops failing silently (FR-14.1 … FR-14.20). **Not yet built:** exposure drag and AE/AF lock (FR-14.13), the flat-lay mark (FR-14.16), low-light torch surfacing (FR-14.17) |
| Data adapters | **complete and green** — SwiftData, file system, ImageIO, Apple Maps |
| Location | **fixed** — ADR-004 amendment, 21 Aug: the 120 m gate moves from the resolver to the preselection that owns it, `startUpdatingLocation` replaces the one-shot `requestLocation`, a transient CoreLocation error no longer ends the wait, and the map gains a control that returns it to the reader (FR-3.11, FR-6.6) |
| App target | **built and running** — 6 screens, verified in the simulator, light and dark |
| E2E tests | **complete and green** — 16 XCUITest journeys, run against stubbed adapters |
