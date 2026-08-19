# ADR-003 — Visual design language

**Date:** 2026-08-19 · **Status:** accepted · **Resolves:** SRS OPEN-1, OPEN-4

## Decision
A **travel-journal / editorial** language: warm paper tones, serif display type, and food
photographs framed like postage stamps on the map. Navigation is **map-first with no tab bar**;
lists and detail arrive in a bottom sheet. The app **follows the device language**, shipping
Vietnamese and English.

## Why this fits the product
The three user stories are about *memory* — what I ate, where I was, what someone told me to
try. A journal aesthetic states that purpose in a way a generic food-delivery look would not.
The stamp framing also does real work: it gives every photo pin a consistent silhouette on a
busy map, regardless of how the dish was photographed.

## The risk, and how it is contained
Serif type and textured surfaces are easy to get wrong at map-label sizes. Two rules contain it:

1. **Serif is for display only** — screen titles, place names, the wordmark. Everything
   functional (buttons, labels, form fields, distances, timestamps) uses the system sans face.
2. **No paper texture behind text.** Warmth comes from flat colour, not from a noise or grain
   overlay, so contrast stays predictable and Dynamic Type keeps working.

## Type
| Role | Face | Notes |
|---|---|---|
| Wordmark, screen titles, place names | **New York** (`.font(.system(.title, design: .serif))`) | Apple's system serif; ships with iOS, so no bundled font and full Dynamic Type support |
| Body, labels, buttons, numbers | **SF Pro** (system default) | Legibility at small sizes; SF Pro Rounded is deliberately avoided as too playful for this language |
| Notes and recommendations | New York italic | Gives the "someone told me this" quality without a script font |

**Vietnamese constraint:** both faces support the full Vietnamese diacritic set, including
stacked marks (`ế`, `ộ`, `ữ`). Line height must be **≥ 1.3×** so stacked diacritics are never
clipped — the usual failure mode for Vietnamese in tightly-leaded editorial layouts. This is
a test-visible property, not a matter of taste.

## Colour tokens
Contrast ratios below are computed, not estimated — `FoodMapDesign` owns the palette and
TC-N-07 recomputes every pairing on each test run. Body text now clears WCAG **AAA** (7:1)
and text on filled controls clears AA (4.5:1); the weakest text pairing is **7.45:1**.
The first palette shipped white-on-tint at 3.03:1 in dark mode — the test caught it, which is
why the numbers live in code rather than in this table alone.

### Light — "paper"
| Token | Hex | Use | Contrast on paper |
|---|---|---|---|
| `paper` | `#F7F2E6` | App background | — |
| `paperRaised` | `#FFFDF7` | Cards, sheets | — |
| `ink` | `#1F1A16` | Primary text | **15.6:1** |
| `inkSecondary` | `#4A423A` | Secondary text | **8.4:1** |
| `rule` | `#8F836E` | Hairlines, stamp perforations | **3.3:1** (component) |
| `lacquer` | `#8C2A1B` | Visited places, primary action | **8.9:1** |
| `jade` | `#1F5244` | Wishlist places | **8.2:1** |
| `onLacquer` / `onJade` | `#FFFFFF` | Text on a filled control | **≥ 7.4:1** on the fill |

### Dark — "night"
| Token | Hex | Use | Contrast on night |
|---|---|---|---|
| `paper` | `#141110` | Background | — |
| `paperRaised` | `#201B17` | Cards, sheets | — |
| `ink` | `#F7F1E6` | Primary text | **16.3:1** |
| `inkSecondary` | `#C3B8A6` | Secondary text | **9.8:1** |
| `rule` | `#776B5F` | Hairlines | **3.6:1** (component) |
| `lacquer` | `#F0937C` | Visited, primary action | **8.7:1** |
| `jade` | `#8FCDB4` | Wishlist | **9.9:1** |
| `onLacquer` / `onJade` | `#141110` | Text on a filled control | **≥ 8.2:1** on the fill |

**Lacquer red and jade green** are drawn from Vietnamese lacquerware rather than picked at
random, which keeps the palette specific to the market without resorting to flag colours.

## Components

### Map pin — the signature element
```
   visited                wishlist
  ┌ ─ ─ ─ ─ ┐            ┌ ─ ─ ─ ─ ┐
  │ ▓▓▓▓▓▓▓ │            │    ✦    │
  │ ▓photo▓ │            │         │
  │ ▓▓▓▓▓▓▓ │            └ ─ ─ ─ ─ ┘
  └ ─ ─ ─ ─ ┘         outlined, jade, dashed
 scalloped edge,
 lacquer border
```
- **Visited:** the photograph, in a scalloped "stamp" frame with a lacquer border.
- **Wishlist:** an empty stamp outline in jade with a bookmark glyph — **shape and fill differ,
  not only colour**, satisfying NFR-6.3 for colour-blind users.
- **Cluster:** stacked stamp edges with a count in the corner, like layered postcards.

### Bottom sheet
The only navigation surface. Three detents: peek (a handle plus one row), half (the list), and
full (place detail). The map is never fully covered at the peek and half detents.

### Cards
`paperRaised`, 1 pt `rule` border, 12 pt corner radius, and a very soft shadow. No heavy
drop shadows — the language is printed paper, not floating glass.

### Chrome is iconographic
The sheet's three actions — add a meal, save a place, near me — are icons on a 44 pt target,
not labelled buttons. Labels in two languages of very different lengths made the row wrap or
clip on the smallest iPhone, and the three glyphs (camera, bookmark, location) are unambiguous.
Every one carries a VoiceOver label, so nothing is lost to a screen reader.

## Motion
Restrained: 200–250 ms ease-out for sheet and pin transitions. One signature moment — a newly
saved meal's stamp settles onto the map with a slight scale-down, like a stamp being pressed.
Everything honours **Reduce Motion**.

## The camera is the first screen (FR-1.10)
Tapping `+` opens the app's own AVFoundation camera immediately, then asks for a score, then
shows a confirm step. The earlier design opened a seven-field form with a "Take a photo" button
inside it, which put paperwork between the user and the food in front of them.

- **Own camera, not the system picker.** Photographing food is the core loop; a stock sheet
  made it feel like a detour. Capture uses `fileDataRepresentation()`, which keeps the EXIF the
  meal's time and place are derived from.
- **One question after the shutter.** The score is asked while the meal is still in front of
  the user; a tap on a star answers it and moves on, and a skip is one tap away.
- **Everything else is derived and shown, not asked.** The place comes from the photo's EXIF
  coordinate or the current fix (FR-1.11); dish name, note and time sit behind one disclosure
  on the confirm step. A wrong guess costs one tap to change — an absent guess costs a search.

## Accessibility (NFR-6)
- Dynamic Type throughout, including the serif display face; no fixed point sizes.
- Every pin carries a VoiceOver label: *"Phở Thìn, been here, 2 meals"*.
- Visited and wishlist differ in shape, fill and glyph — never colour alone.
- Minimum touch target 44×44 pt, so stamp pins are at least that size regardless of art.

## Language (resolves OPEN-4)
The app follows the device language, with Vietnamese and English bundled. All user-facing
strings live in a string catalogue from the first screen — retrofitting localisation is far
more expensive than starting with it.

## Consequences
- A `DesignSystem` folder holds the tokens; no view hard-codes a colour or a font size.
- Dark mode is a first-class variant, defined here rather than discovered later.
- **A test asserts Vietnamese diacritics are not clipped**, since it is the specific failure
  mode this style invites.
- The palette lives in `FoodMapDesign`, a package with no UIKit dependency, so contrast is
  computed and asserted (TC-N-07) rather than eyeballed in the simulator.
- Camera permission is now a real dependency of the primary flow; refusal is handled inside the
  camera screen, which offers the photo library instead rather than dead-ending.
