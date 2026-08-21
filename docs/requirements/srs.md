# Software Requirements Specification — Nomstamp

**Version:** 0.1 (draft) · **Date:** 2026-08-19 · **Status:** for review

---

## 1. Introduction

### 1.1 Purpose
This document specifies the requirements for **Nomstamp**, an iPhone application that lets one
person remember the food they have eaten and the places they still want to try, both plotted
on a map. It is the authoritative source for what the product must do; `use-cases.md` describes
how users achieve it, and `test-cases.md` defines how each requirement is proven.

### 1.2 Scope
Nomstamp is a **personal, on-device** food diary and wishlist on a map. A user photographs a
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
A standalone iPhone app with **no backend we run**. All user data — meals, notes and photographs —
is stored in the device's own container. The external services contacted are Apple Maps, for map
tiles and place lookup, and, once a reader connects a friend, Apple's CloudKit, which carries sealed
stamps between the two of them (ADR-009). There is no server to deploy and nothing to pay for:
records live in each reader's own iCloud quota. Identity is an ed25519 keypair the device generates
for itself; connecting a friend additionally requires an Apple ID signed into iCloud.

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
| CON-1 | No backend we run, no server to deploy, no account we hold. An Apple ID is required for the friends feature and for nothing else | Product decision, amended by ADR-009 |
| CON-2 | No paid APIs and no API keys shipped in the app | ADR-001 |
| CON-3 | Nothing leaves the device except by an explicit per-place share, and never more than a shared stamp defines | Privacy decision, ADR-008, carried by ADR-009 |
| CON-4 | iPhone only; no iPad or Android. Since ADR-009 this is permanent rather than a current choice — CloudKit closes the door | Product decision, ADR-009 |
| CON-5 | Clean architecture with domain logic free of Apple frameworks | ADR-002 |
| CON-6 | Every use-case flow covered by an automated test | ADR-002 |

### 2.5 Assumptions and dependencies
- **A-1** Apple Maps place data is adequate for Vietnamese cities. *Measured, see ADR-001:
  ~50 food places within 500 m in Hanoi, HCMC, Đà Nẵng and Hội An.*
- **A-2** Much Vietnamese street food is in **no** commercial database, so a manual pin-drop
  path is mandatory rather than a fallback.
- **A-3** The device has enough free storage for the user's photo library growth.
- **A-4** One user per device; no multi-user or profile switching.
- **A-5** Friends are peers, not followers: a connection is mutual and both sides hold each
  other's key.
- **A-6** A reader who wants friends has an Apple ID signed into iCloud. Without one the friends
  feature is unavailable and the rest of the app is unaffected (ADR-009).

---

## 3. Functional requirements

Each requirement names the use case it comes from and the test cases that prove it.

### FR-1 Meal logging
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-1.1 | The user shall log a meal consisting of at least one photograph, a time and a place | UC-1 | TC-1-01 |
| FR-1.2 | The system shall reject a meal with no photograph | UC-1 | TC-1-01 (rejectsEmptyPhotoList) |
| FR-1.3 | The system shall derive the meal time from the photograph's own metadata when present, and from the device clock otherwise. An EXIF timestamp shall be read in the photograph's own UTC offset when it records one, and in the device's time zone otherwise — never as UTC | UC-1/1a | TC-1-04, TC-1-05, TC-1-20 |
| FR-1.4 | The system shall let the user override the derived meal time | UC-1 | TC-1-15 |
| FR-1.5 | The user shall optionally record dish name, rating (1–5), note and price | UC-1 | TC-1-01 |
| FR-1.6 | Logging a meal shall succeed when location permission is denied | UC-1/E1 | TC-1-03 |
| FR-1.7 | Logging a meal shall succeed when no network is available | UC-1/6a | TC-1-10 |
| FR-1.8 | If storing any photograph fails, the meal shall not be persisted and no orphaned file shall remain | UC-1/E2 | TC-1-08 |
| FR-1.9 | Multiple photographs shall be attachable to one meal, preserving their order | UC-1 | TC-1-09 |
| FR-1.10 | Logging shall proceed camera → rating → confirm: the camera shall open immediately on **Add meal**, the score shall be asked once **on leaving the camera** — about the meal, not about a photograph, so several dishes may be photographed first (FR-14.15) — and every derived value shall be editable on the confirm step | UC-1 | TC-1-19, TC-1-33 |
| FR-1.11 | The system shall preselect the place from the meal's coordinate — the nearest saved place within 120 m, else the nearest search candidate within 120 m — without the user choosing one | UC-1/3 | TC-1-16, TC-1-17 |
| FR-1.12 | A failure or absence of the place directory, or of any coordinate, shall leave the place unset rather than raise an error | UC-1/E1, UC-1/6a | TC-1-18 |
| FR-1.13 | A device fix shall be used only when its reported horizontal accuracy is valid and no coarser than the 120 m preselection radius; a coarser fix shall count as no coordinate rather than as a guess | UC-1/3, UC-1/E1 | TC-1-21, TC-1-22 |
| FR-1.14 | A device fix older than 60 s shall not be reused, including when the wait for a new fix times out | UC-1/3 | TC-1-23 |
| FR-1.15 | While location permission is undecided, the system shall ask for it and await the answer before concluding that no coordinate is available | UC-1/E1 | TC-1-24 |
| FR-1.16 | Where a meal's photographs disagree, its time and coordinate shall both be taken from the earliest photograph that carries a coordinate | UC-1/1a | TC-1-25 |
| FR-1.17 | A photographed coordinate of exactly 0°, 0° shall be treated as absent, since cameras write it in place of a missing fix | UC-1/1a | TC-1-26 |

### FR-2 Photograph storage
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-2.1 | Photographs shall be stored in the application's own container. Originals shall never be transmitted; only 240 px thumbnails leave, and only under FR-11 | CON-3 | TC-1-11 |
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

### FR-9 Rating a meal
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-9.1 | The user shall rate a meal from 1 to 5 while logging it | UC-7 | TC-7-01 |
| FR-9.2 | The user shall change or clear the rating of a meal already logged | UC-7/1a, 1b | TC-7-02, TC-7-03 |
| FR-9.3 | A score outside 1–5 shall be rejected, leaving the meal unchanged | UC-7/E1 | TC-7-04 |
| FR-9.4 | A place shall report the average of its rated meals, ignoring unrated ones | UC-7 | TC-7-05 |
| FR-9.5 | Ratings shall be reachable in one tap from the meal, with no separate edit screen | UC-7/1a | TC-7-06 |

### FR-10 Identity and connecting a friend
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-10.1 | The device shall generate an ed25519 keypair on first launch and hold the private key in the Keychain | UC-8 | TC-8-03 |
| FR-10.2 | Friends shall be connectable **only in person**, over local radio: Bluetooth presence, a proximity gate, and a matching word confirmed on both devices | UC-8 | TC-8-08, TC-8-09 |
| FR-10.3 | A connection shall not be establishable remotely by any means, including a forwarded QR code | UC-8/E1 | TC-8-08 |
| FR-10.4 | Connecting shall require both readers to confirm the same matching word, and each shall name the other before any data flows | UC-8 | TC-8-06, TC-8-07 |
| FR-10.5 | A connection shall be mutual; one-way following shall not exist | UC-8 | TC-8-05 |
| FR-10.6 | A friend's name shall be the one the reader assigned, never the one the friend asserted; the key fingerprint shall be available on the friend's own screen | UC-8 | TC-8-05 | *(where the fingerprint belongs is OPEN-8)*
| FR-10.7 | Removing a friend shall delete their stamps and revoke the connection | UC-8/2a | TC-8-10 |
| FR-10.8 | The friend list shall be capped at **eight**; a full circle shall be explained and offer removal, never presented as an error | UC-8/E2 | TC-8-01, TC-8-02 |
| FR-10.9 | The first sync shall run immediately on connecting, over the local radio link and without a network | UC-8 | TC-8-11 |
| FR-10.10 | No part of the connect path shall use infrastructure networking — not the local network, not CloudKit, not the internet — so that proximity is enforced by radio range rather than by a check | UC-8/E1 | TC-8-08 |
| FR-10.11 | The device shall be discoverable only while the *Add friend* screen is open, and shall advertise an ephemeral identifier rather than its public key | UC-8 | TC-8-12 |
| FR-10.12 | The *Add friend* screen shall **start** discovery when it appears and **stop** it when it leaves; a screen that only reads the results of a scan nobody started shall be considered broken | UC-8 | TC-8-14, TC-8-15 |
| FR-10.13 | Where the radio is off, unauthorised or unsupported, the screen shall say so and offer the way to fix it, rather than searching forever | UC-8/E3 | TC-8-16, TC-8-17 |

### FR-11 Sharing a place
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-11.1 | No place shall be shared unless the user explicitly shares it | UC-9 | TC-9-01 |
| FR-11.2 | A shared stamp shall carry only place, **kind** (been there or want to try), average rating, visit count, latest dish, month last visited and one thumbnail. Everything but place and kind shall be optional, because a place nobody has been to has none of them (ADR-010) | UC-9 | TC-9-02, TC-9-17 |
| FR-11.3 | A shared stamp shall never carry price, per-meal ratings, exact dates or full-size photographs | UC-9 | TC-9-03, TC-9-04 |
| FR-11.4 | A note shall be shared only where the user opted in for that place | UC-9/1a | TC-9-10 |
| FR-11.5 | Every thumbnail shall be re-encoded from pixels before it leaves, carrying nothing about where, when or with what it was taken. The geometry an encoder must write — colour space and pixel dimensions — is permitted; a GPS, TIFF, IPTC, ExifAux or maker-note block is not | UC-9 | TC-9-09, TC-9-16 |
| FR-11.6 | Unsharing a place shall propagate a retraction on the next connection | UC-9/2a | TC-9-14 |

### FR-12 Friends' stamps on the map
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-12.1 | Friends' stamps shall appear as their own map layer, off by default | UC-10 | TC-10-01 |
| FR-12.2 | A friend's place matching one the user has also stamped shall render as **one pin, drawn exactly as the user's own** — no countersignature, no numeral. Who stamped it is a question the place page answers (ADR-010) | UC-10 | TC-10-05, TC-10-06 |
| FR-12.3 | Matching shall use `providerPlaceID` first, then name-and-distance, then stand alone | UC-10 | TC-10-02, TC-10-03 |
| FR-12.4 | Each friend shall have a deterministic ink derived from their public key, drawn from a fixed plate of eight that the skin does not re-ink. The ink shall identify them **where they are named** — the place page, the friends list, the filter — and shall not be drawn on a map pin (ADR-010). Its name shall be distinct from the other seven **in every language**, first word included (NFR-5.6) | UC-10 | TC-8-03, TC-N-25, TC-N-27 |
| FR-12.5 | A friend's place shall be drawn **identically** to the user's own: same pin, same cut, same ink, same wishlist bookmark. The map answers *where is worth eating*, not *whose is this* (ADR-010) | UC-10 | TC-10-24 |
| FR-12.5a | A friend's **wishlist** shall travel and be drawn, as a wishlist place — a recommendation is at least as useful as a memory (ADR-010) | UC-10 | TC-10-25 |
| FR-12.6 | A friend's stamps shall be shown with the date that friend was last reached, never implied to be current. The date shall belong to the friend, not to individual stamps | UC-10 | TC-10-08 |
| FR-12.7 | The interface shall never state what a friend shares now, only what was held as of the last exchange | UC-10 | TC-10-08 |
| FR-12.8 | A place's own page shall name every friend who has also stamped it, in ink order. Unlike the map layer, this list shall not depend on the layer switch — the switch governs the drawing, and a page the user opened deliberately is a different question | UC-10 | TC-10-16 |
| FR-12.9 | The filter shall show each friend's **name** beside their ink. With every pin drawn alike, the filter is how the map is read rather than a convenience, and a strip of unlabelled colours filters nothing anyone can aim | UC-10 | TC-10-17 |
| FR-12.10 | Every friend-attributed element shall name that friend to VoiceOver, and shall name their ink — a reader who cannot see the hue is exactly the reader for whom the strip of colours does no work (NFR-6.2) | UC-10 | TC-10-18, TC-10-19 |
| FR-12.11 | A reader shall be able to hide any friend's places, and to **isolate** one — *show only Lan* — without switching the other seven off one at a time. Isolating shall be reversible in a single action | UC-10 | TC-10-20, TC-10-21 |
| FR-12.11a | The map shall be filterable by **kind** — been there, want to try, or both — and the two filters shall compose, because *Lan's wishlist* is a more natural question than either half alone (ADR-010) | UC-10 | TC-10-26, TC-10-27 |
| FR-12.12 | Isolating shall be reachable without a gesture that cannot be seen: whatever the pointer affordance, VoiceOver shall offer it as a named action | UC-10/NFR-6.2 | TC-10-22 (manual) |

### FR-13 Synchronising
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-13.1 | Changes shall reach a friend without both devices being awake together: the sharing device writes to its shared zone, and a subscription wakes the receiving device | UC-10 | TC-8-13 |
| FR-13.1a | Arriving stamps shall wake the application only, never the reader. No notification shall be raised | UC-10 | TC-10-09 |
| FR-13.2 | Reconciliation shall exchange a manifest and transfer only what changed | UC-10 | TC-10-11 |
| FR-13.3 | Thumbnails shall be addressed by content hash and never fetched twice | UC-10 | TC-10-13 |
| FR-13.3a | A shared stamp's version shall follow a content hash of the projection, so that an edit changing nothing shareable causes no traffic | UC-9 | TC-9-11, TC-9-12 |
| FR-13.3b | The projection shall be recomputed whenever the underlying place or its meals change, not only when sharing is toggled | UC-9 | TC-9-13 |
| FR-13.3c | Stamps and thumbnails shall be sealed with a per-stamp content key, wrapped once per friend, before leaving the device | UC-9 | TC-9-17 |
| FR-13.4 | Friend data shall be a disposable cache, reconstructible by re-syncing | UC-10 | TC-10-12 |
| FR-13.5 | Failure to reach a friend shall never surface as an error, only as staleness | UC-10/E1 | TC-10-10 |
| FR-13.6 | The whole friends feature shall be optional; with no friends or no network the app shall behave exactly as before | UC-10 | TC-10-14 |

### FR-14 Capture *(ADR-011)*
| ID | Requirement | UC | Tests |
|---|---|---|---|
| FR-14.1 | The reader shall be able to photograph with either the front or the back camera, switching between them from the viewfinder | UC-1 | TC-1-27, TC-1-31 |
| FR-14.2 | The back camera shall be chosen by discovery — triple, then dual-wide, then wide-angle — so that automatic macro switching is available for close-ups of food. `default(for:)` shall not be used, because it returns the one device that cannot focus close | UC-1 | TC-1-27 |
| FR-14.3 | The front camera shall be chosen as TrueDepth, then wide-angle | UC-1 | TC-1-27 |
| FR-14.4 | The chosen side shall not persist between meals; each meal shall open on the back camera | UC-1 | TC-1-31 |
| FR-14.5 | The viewfinder shall support pinch zoom, clamped to the device maximum, and a 1x/2x tap where the device offers it | UC-1 | TC-1-31 |
| FR-14.6 | A tap on the preview shall set focus **and** exposure at that point, and shall be shown; a second tap or a camera flip shall return to continuous auto | UC-1 | TC-1-31 |
| FR-14.7 | Where the device has a torch, an off/on/auto control shall be offered, defaulting to off and not persisting. Where it has none, the control shall be absent rather than disabled | UC-1 | TC-1-31 |
| FR-14.8 | The capture connection's rotation shall be set from the device orientation at the moment of capture, so a photograph taken sideways is not stored with portrait orientation | UC-1 | TC-1-28, TC-1-31 |
| FR-14.9 | Every capture shall confirm itself with a haptic and a viewfinder dim before the photograph is processed | UC-1 | TC-1-31 |
| FR-14.10 | A capture that yields no data shall tell the reader and invite a retry, never fail silently | UC-1/E2, NFR-4.4 | TC-1-29 |
| FR-14.11 | Either volume button shall fire the shutter, so the one control on the viewfinder that can be found without looking is available to a reader holding the phone over a bowl one-handed | UC-1 | TC-1-31 |
| FR-14.12 | Where the device has more than one back lens, the viewfinder shall offer 0.5x / 1x / 2x marks showing which is live; pinch shall continue to work and shall move them | UC-1 | TC-1-31 |
| FR-14.13 | After a tap sets focus and exposure, a vertical drag shall adjust exposure bias, and a long press shall lock focus and exposure until the camera is flipped or the meal saved | UC-1 | TC-1-31 |
| FR-14.14 | After a capture the viewfinder shall show a thumbnail of the shot just taken, with a count; tapping it shall review the shot full-screen, from where it may be discarded | UC-1 | TC-1-32 |
| FR-14.15 | The viewfinder shall not be left until the reader leaves it: several photographs may be taken in one visit, and the rating shall be asked once on the way out, about the meal rather than the photograph | UC-1 | TC-1-32, TC-1-33 |
| FR-14.16 | Where the phone is within a few degrees of level and facing down, a mark shall confirm it. Nothing shall be enforced or blocked, and the mark shall be absent otherwise | UC-1 | TC-1-31 |
| FR-14.17 | In low light the torch control shall surface itself and shall not switch itself on | UC-1, NFR-4.7 | TC-1-31 |
| FR-14.18 | Capture shall set quality prioritisation and maximum photo dimensions explicitly rather than accepting the defaults; NFR-8.1's storage cap shall be applied after capture, never before | UC-1 | TC-1-34 |
| FR-14.19 | The front preview shall be mirrored and the stored photograph shall not, so that text behind the reader remains readable | UC-1 | TC-1-31 |
| FR-14.20 | The app shall not offer filters, a rule-of-thirds grid, timers, burst, video or RAW. The camera serves the notebook; it is not the product | ADR-011 | — |

---

## 4. Non-functional requirements

### NFR-1 Privacy *(the product's core promise)*
- **NFR-1.1** Nothing shall be transmitted off the device automatically. A place leaves only when
  the user shares that place, and then only the fields FR-11.2 permits.
- **NFR-1.2** No analytics, telemetry, advertising identifier or crash reporter shall be included.
- **NFR-1.3** Outbound traffic shall be limited to Apple Maps requests and, once a friend is
  connected, Apple's CloudKit. There shall be no traffic at all before a friend is connected.
- **NFR-1.4** No account, login or personally identifying data shall be collected **by us**. Identity
  is a keypair the device generates. An Apple ID is required to reach a friend, and Apple therefore
  learns which accounts share a zone; that metadata is the cost, and it is stated rather than hidden.
- **NFR-1.5** Shared data shall be sealed on the device before it is written anywhere. No third
  party, Apple included, shall be able to **read** it — independently of whether the reader has
  Advanced Data Protection enabled.
- **NFR-1.6** Photographs that leave shall be 240 px thumbnails with EXIF stripped, never originals.
- **NFR-1.7** Retraction is best-effort by design: unsharing propagates on the next connection and
  shall never be described to the user as immediate deletion.
- **NFR-1.8** The connect ceremony shall reveal a reader's chosen name to nearby devices only while
  the *Add friend* screen is open, and shall never broadcast a stable identifier.
- *Verification:* a network-traffic inspection during an e2e run shows no host other than Apple's,
  and no traffic at all before a friend is connected.

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
- **NFR-4.5** No two shipped strings shall carry the same meaning under different words. One idea
  has one word, recorded in the lexicon of the voice note (21 Aug). *(TC-N-30, TC-N-33)*
- **NFR-4.6** Every error and every empty state shall name an action the reader can take.
  *(TC-N-32)*
- **NFR-4.7** A message about a permission or a limit shall name what the app has not been allowed
  or cannot do, never phrase it as the reader's failing. *(voice note, 21 Aug)*

### NFR-5 Localisation and internationalisation
- **NFR-5.1** The interface shall support **Vietnamese and English**.
- **NFR-5.2** Vietnamese text, including diacritics, shall render correctly throughout.
- **NFR-5.3** Text matching and search shall be diacritic- and case-insensitive (FR-5.5).
- **NFR-5.4** Distances shall use the metric system.
- **NFR-5.5** Vietnamese shall be written rather than translated: no `được … bởi` passive
  construction, and no English sentence rendered word-for-word. Where the two languages want
  different sentences, they shall get different sentences. *(TC-N-31)*
- **NFR-5.6** A property the interface guarantees in one language shall be guaranteed in **every**
  language. Tests that read the string catalogue shall read all of it, not the English alone.
  *(TC-N-27, extended; voice note 21 Aug §6)*

### NFR-6 Accessibility
- **NFR-6.1** The interface shall support Dynamic Type up to the accessibility sizes.
- **NFR-6.2** All controls and map pins shall carry VoiceOver labels.
- **NFR-6.3** Colour shall never be the only means of distinguishing visited from wishlist pins. Whose place it is, is deliberately not drawn on the map at all (ADR-010, FR-12.5) — it is answered by the place page and by the filter, so there is no colour-only signal to fall back from.
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
| ~~OPEN-5~~ | ~~How often two friends' phones are awake together~~ | **No longer applicable** — ADR-009 removed the both-awake constraint |
| ~~OPEN-6~~ | ~~Direct-connection rate over Vietnamese mobile carriers, which lean on CGNAT~~ | **No longer applicable** — ADR-009 drops hole-punching |
| OPEN-7 | Whether eight friends proves too tight in use. Raising the cap is invisible and safe; lowering it orphans existing connections | Post-v1 |
| OPEN-3 | Whether ratings are stars, a simple like, or absent | FR-1.5 |
| ~~OPEN-4~~ | ~~Vietnamese or English as the default language on first launch~~ | **Resolved** — follows the device language, see ADR-003 |
| OPEN-8 | Whether locally-assigned names fully retire the fingerprint-wherever-trusted rule, or whether a fingerprint stays in the everyday interface (ADR-009) | FR-10.6 |
| OPEN-9 | Whether the bulk share joins the connect ceremony, so a first connection does not land an empty layer at the table (ADR-009) | UC-8, FR-11.1 |
| OPEN-10 | Whether the fresh-ink decay is worth a per-stamp *first seen* date — the first friend data not reconstructible by re-syncing (ADR-009) | FR-13.4 |
| OPEN-11 | How reliably a silent push wakes the app for a shared-zone change after days unopened | **Spike before build** |
| OPEN-12 | `quotaExceeded` for readers who are non-primary members of a Family iCloud plan | **Spike before build** |
| OPEN-13 | The RSSI threshold that means *across this table* rather than *across this restaurant* | **Spike before build** |
