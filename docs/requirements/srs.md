# Software Requirements Specification — Food Map

**Version:** 0.1 (draft) · **Date:** 2026-08-19 · **Status:** for review

---

## 1. Introduction

### 1.1 Purpose
This document specifies the requirements for **Food Map**, an iPhone application that lets one
person remember the food they have eaten and the places they still want to try, both plotted
on a map. It is the authoritative source for what the product must do; `use-cases.md` describes
how users achieve it, and `test-cases.md` defines how each requirement is proven.

### 1.2 Scope
Food Map is a **personal, on-device** food diary and wishlist on a map. A user photographs a
dish where they eat it, and the photo becomes a pin at that restaurant. A user can also save a
place they have merely heard about, and later find it again when they are nearby.

**In scope (v1):** meal logging with photos, map browsing, place detail, wishlist saving,
proximity discovery, and the transition from wishlist to visited.

**Out of scope (v1):** sharing, social features, following other users, public feeds, comments,
accounts, cross-device sync, Android, iPad, offline map tiles, and restaurant booking.

### 1.3 Definitions
| Term | Meaning |
|---|---|
| **Place** | A restaurant, café or food stall pinned on the user's map |
| **Meal** | One sitting at a place, holding one or more photos |
| **Visited place** | A place with at least one meal logged |
| **Wishlist place** | A place saved but never eaten at — no meals yet |
| **Pin** | A place's marker on the map; for visited places it shows the food photo |
| **Provider** | The external service supplying place names and coordinates (Apple Maps) |

### 1.4 References
- `user-stories.md` — the three originating user stories
- `use-cases.md` — UC-1 … UC-6
- `../architecture/adr-001-map-and-search.md` — map provider and search, with Vietnam measurements
- `../architecture/adr-002-architecture-and-testing.md` — layering, patterns and test strategy
- `../testing/test-cases.md` — TC-1-01 … TC-X-06
- `../workflow.md` — docs → test cases → test code → code

---

## 2. Overall description

### 2.1 Product perspective
A standalone iPhone app with **no backend of any kind**. All user data — meals, notes and
photographs — is stored in the device's own container. The only external service contacted is
Apple Maps, for map tiles and place lookup. There is no account, no login and no server to run.

### 2.2 User characteristics
A single private user. Assumed to be an ordinary smartphone owner, not a technical user.
The primary market is **Vietnam**, so Vietnamese place names, diacritics and the prevalence of
unlisted street food are first-order design concerns, not localisation afterthoughts.

### 2.3 Operating environment
- iPhone only, **iOS 18.0 or later**, portrait orientation.
- Requires the camera or photo library, and GPS for the location-based flows.
- Requires a network connection for map tiles and place search; **not** for logging a meal.

### 2.4 Design and implementation constraints
| ID | Constraint | Source |
|---|---|---|
| CON-1 | No backend, no server, no user accounts | Product decision |
| CON-2 | No paid APIs and no API keys shipped in the app | ADR-001 |
| CON-3 | Photographs never leave the device | Privacy decision |
| CON-4 | iPhone only; no iPad or Android | Product decision |
| CON-5 | Clean architecture with domain logic free of Apple frameworks | ADR-002 |
| CON-6 | Every use-case flow covered by an automated test | ADR-002 |

### 2.5 Assumptions and dependencies
- **A-1** Apple Maps place data is adequate for Vietnamese cities. *Measured, see ADR-001:
  ~50 food places within 500 m in Hanoi, HCMC, Đà Nẵng and Hội An.*
- **A-2** Much Vietnamese street food is in **no** commercial database, so a manual pin-drop
  path is mandatory rather than a fallback.
- **A-3** The device has enough free storage for the user's photo library growth.
- **A-4** One user per device; no multi-user or profile switching.

---

## 3. Functional requirements

Each requirement names the use case it comes from and the test cases that prove it.

### FR-1 Meal logging
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-1.1 | The user shall log a meal consisting of at least one photograph, a time and a place | UC-1 | TC-1-01 |
| FR-1.2 | The system shall reject a meal with no photograph | UC-1 | TC-1-01 (rejectsEmptyPhotoList) |
| FR-1.3 | The system shall derive the meal time from the photograph's own metadata when present, and from the device clock otherwise | UC-1/1a | TC-1-04, TC-1-05 |
| FR-1.4 | The system shall let the user override the derived meal time | UC-1 | TC-1-15 |
| FR-1.5 | The user shall optionally record dish name, rating (1–5), note and price | UC-1 | TC-1-01 |
| FR-1.6 | Logging a meal shall succeed when location permission is denied | UC-1/E1 | TC-1-03 |
| FR-1.7 | Logging a meal shall succeed when no network is available | UC-1/6a | TC-1-10 |
| FR-1.8 | If storing any photograph fails, the meal shall not be persisted and no orphaned file shall remain | UC-1/E2 | TC-1-08 |
| FR-1.9 | Multiple photographs shall be attachable to one meal, preserving their order | UC-1 | TC-1-09 |
| FR-1.10 | Logging shall proceed camera → rating → confirm: the camera shall open immediately on **Add meal**, the score shall be asked once a photo exists, and every derived value shall be editable on the confirm step | UC-1 | TC-1-19 |
| FR-1.11 | The system shall preselect the place from the meal's coordinate — the nearest saved place within 120 m, else the nearest search candidate within 120 m — without the user choosing one | UC-1/3 | TC-1-16, TC-1-17 |
| FR-1.12 | A failure or absence of the place directory, or of any coordinate, shall leave the place unset rather than raise an error | UC-1/E1, UC-1/6a | TC-1-18 |

### FR-2 Photograph storage
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-2.1 | Photographs shall be stored in the application's own container and never transmitted | CON-3 | TC-1-11 |
| FR-2.2 | A thumbnail shall be generated for each photograph for use on map pins | UC-2 | TC-1-11 |
| FR-2.3 | The system shall read capture time and GPS coordinates from image metadata, handling southern and western hemispheres correctly | UC-1/1a | TC-1-12 |
| FR-2.4 | Absent image metadata shall not be an error | UC-1/1a | TC-1-13 |
| FR-2.5 | Deleting a meal or place shall delete its image files from disk | UC-3 | TC-3-04, TC-3-05 |

### FR-3 Map browsing
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-3.1 | The map shall display a pin for each saved place within the visible area | UC-2 | TC-2-01 |
| FR-3.2 | A visited place's pin shall display a photograph of the food eaten there | UC-2 | TC-2-07 |
| FR-3.3 | Visited and wishlist pins shall be visually distinguishable without interaction | UC-2 | TC-2-03 |
| FR-3.4 | Several meals at one place shall render as exactly one pin, indicating the meal count | UC-2/3a | TC-2-02 |
| FR-3.5 | Pins too close to distinguish shall be clustered, and expand on zoom | UC-2 | TC-2-04, TC-2-05 |
| FR-3.6 | Clustering shall neither drop nor duplicate any place | UC-2 | TC-2-09 |
| FR-3.7 | A cluster of one place shall be drawn at that place's exact coordinate | UC-2 | TC-2-06 |
| FR-3.8 | The user shall filter the map by visited or wishlist | UC-2/5a | TC-2-08 |
| FR-3.9 | With no places saved, the map shall show an explanatory empty state | UC-2/1a | TC-2-10 |
| FR-3.10 | Tapping a pin shall open that place, exactly as tapping its row does; tapping a cluster shall list the places inside it, and choosing one shall open it | UC-2/6, UC-3 | TC-2-11 |

### FR-4 Place detail
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-4.1 | Opening a place shall list every meal eaten there, newest first | UC-3 | TC-3-01 |
| FR-4.2 | A wishlist place shall display the note explaining why it was saved | UC-3/2a | TC-3-02 |
| FR-4.3 | A wishlist place shall offer a single action to log a meal there | UC-3/2a | TC-6-05 |
| FR-4.4 | The user shall delete a meal or a whole place | UC-3 | TC-3-03 |
| FR-4.5 | The user shall obtain directions to a place | UC-3 | TC-3-06 |
| FR-4.6 | Opening a place shall centre the map on its coordinate and present the place over the map without covering it, so the pin is visible while its meals are read. No separate "show on map" action is needed | UC-3/step 1 | TC-3-07 |

### FR-5 Saving a place heard about
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-5.1 | The user shall save a place found by name search as a wishlist place | UC-4 | TC-4-01 |
| FR-5.2 | The user shall attach a note and tags explaining the recommendation | UC-4 | TC-4-01, TC-4-07 |
| FR-5.3 | The user shall save a place by dropping a pin manually and typing a name | UC-4/2a | TC-4-06 |
| FR-5.4 | Saving a place already on the map shall return the existing place, not create a duplicate | UC-4/3a | TC-4-02, TC-4-03 |
| FR-5.5 | Duplicate detection shall be insensitive to case and Vietnamese diacritics | UC-4/3a | TC-4-05 |
| FR-5.6 | Two same-named places far apart shall remain distinct places | UC-4/3a | TC-4-04 |

### FR-6 Proximity discovery
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-6.1 | The user shall list saved places within a chosen radius of their location, nearest first | UC-5 | TC-5-01 |
| FR-6.2 | Places beyond the radius shall be excluded | UC-5 | TC-5-02 |
| FR-6.3 | Having nothing saved nearby shall be reported as an explicit, successful empty result | UC-5/2a | TC-5-03 |
| FR-6.4 | An unavailable location shall be reported distinctly from an empty result | UC-5 | TC-5-04 |
| FR-6.5 | Both visited and wishlist places shall be included | UC-5 | TC-5-05 |

### FR-7 Place search
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-7.1 | The system shall suggest nearby food places using the provider's category filter | UC-1 | TC-4-08 |
| FR-7.2 | The system shall **never** issue a bare category word as a free-text query | ADR-001 | TC-4-08 |
| FR-7.3 | The system shall search places by name, biased toward a given area | UC-4 | TC-4-08 |
| FR-7.4 | Search failure shall degrade to the manual pin-drop path, never block the user | UC-1/6a | TC-1-10 |
| FR-7.5 | Places already saved shall be offered ahead of provider results | UC-1/4b | TC-1-06 |

### FR-8 Wishlist to visited
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-8.1 | Logging a meal at a wishlist place shall make it a visited place | UC-6 | TC-6-01 |
| FR-8.2 | The original recommendation note shall survive the transition | UC-6 | TC-6-02 |
| FR-8.3 | The place's identity shall be preserved — converted, not replaced | UC-6 | TC-6-03 |
| FR-8.4 | Deleting the last meal shall revert the place to a wishlist place | UC-6 | TC-6-04 |

---

## 4. Non-functional requirements

### FR-9 Rating a meal
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-9.1 | The user shall rate a meal from 1 to 5 while logging it | UC-7 | TC-7-01 |
| FR-9.2 | The user shall change or clear the rating of a meal already logged | UC-7/1a, 1b | TC-7-02, TC-7-03 |
| FR-9.3 | A score outside 1–5 shall be rejected, leaving the meal unchanged | UC-7/E1 | TC-7-04 |
| FR-9.4 | A place shall report the average of its rated meals, ignoring unrated ones | UC-7 | TC-7-05 |
| FR-9.5 | Ratings shall be reachable in one tap from the meal, with no separate edit screen | UC-7/1a | TC-7-06 |

### NFR-1 Privacy *(the product's core promise)*
- **NFR-1.1** No photograph, note, rating or place shall be transmitted off the device.
- **NFR-1.2** No analytics, telemetry, advertising identifier or crash reporter shall be included.
- **NFR-1.3** The only outbound network traffic shall be Apple Maps tile and place requests.
- **NFR-1.4** No account, login or personally identifying data shall be collected.
- *Verification:* a network-traffic inspection during an e2e run shows no host other than Apple's.

### NFR-2 Performance
- **NFR-2.1** Cold launch to an interactive map: **≤ 2 s** on an iPhone 12 or newer.
- **NFR-2.2** Map panning and zooming with 500 saved places: **≥ 55 fps**.
- **NFR-2.3** Saving a meal with one photograph: **≤ 1 s** from tapping Save to confirmation.
- **NFR-2.4** Map pins shall render from thumbnails, never full-size images.

### NFR-3 Reliability
- **NFR-3.1** No user data loss: a failed save shall leave the store exactly as it was (FR-1.8).
- **NFR-3.2** Meal logging shall function with no network connection.
- **NFR-3.3** The app shall not crash on denied camera, photo or location permissions.

### NFR-4 Usability
- **NFR-4.1** Logging a meal shall take **no more than 3 taps** beyond taking the photograph.
- **NFR-4.2** Every destructive action shall be confirmed or undoable.
- **NFR-4.3** Empty states shall explain what to do next, never show a blank screen.
- **NFR-4.4** Error messages shall state what happened and what the user can do.

### NFR-5 Localisation and internationalisation
- **NFR-5.1** The interface shall support **Vietnamese and English**.
- **NFR-5.2** Vietnamese text, including diacritics, shall render correctly throughout.
- **NFR-5.3** Text matching and search shall be diacritic- and case-insensitive (FR-5.5).
- **NFR-5.4** Distances shall use the metric system.

### NFR-6 Accessibility
- **NFR-6.1** The interface shall support Dynamic Type up to the accessibility sizes.
- **NFR-6.2** All controls and map pins shall carry VoiceOver labels.
- **NFR-6.3** Colour shall never be the only means of distinguishing visited from wishlist pins.
- **NFR-6.4** Text contrast shall meet WCAG **AAA** (7:1) for body text and AA (4.5:1) for text on filled controls; enforced by TC-N-07.

### NFR-7 Maintainability and testability
- **NFR-7.1** Domain logic shall not import SwiftUI, SwiftData, MapKit or UIKit (CON-5).
- **NFR-7.2** Domain unit tests shall run on macOS without a simulator, completing in **< 5 s**.
- **NFR-7.3** Every use-case flow shall have at least one automated test (CON-6).
- **NFR-7.4** The place-search provider shall be replaceable without changing domain or UI code.
- **NFR-7.5** Automated tests shall not depend on live network services by default.

### NFR-8 Storage
- **NFR-8.1** Stored images shall be capped at 2048 px on the longest side.
- **NFR-8.2** Thumbnails shall be square and no larger than 240 px.
- **NFR-8.3** Deleting data shall reclaim the corresponding disk space (FR-2.5).

---

## 5. Requirements not yet decided

| ID | Open question | Blocking |
|---|---|---|
| ~~OPEN-1~~ | ~~Visual design language and colour palette~~ | **Resolved** — travel-journal/editorial, see ADR-003 |
| OPEN-2 | Whether photo backup/export is offered, given there is no server | Post-v1 |
| OPEN-3 | Whether ratings are stars, a simple like, or absent | FR-1.5 |
| ~~OPEN-4~~ | ~~Vietnamese or English as the default language on first launch~~ | **Resolved** — follows the device language, see ADR-003 |
