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
| `pandan` | `#0B5E45` | Visited places, primary action | **8.6:1** |
| `bay` | `#15496F` | Wishlist places | **9.4:1** |
| `onPandan` / `onBay` | `#FFFFFF` | Text on a filled control | **≥ 7.4:1** on the fill |

### Dark — "night"
| Token | Hex | Use | Contrast on night |
|---|---|---|---|
| `paper` | `#141110` | Background | — |
| `paperRaised` | `#201B17` | Cards, sheets | — |
| `ink` | `#F7F1E6` | Primary text | **16.3:1** |
| `inkSecondary` | `#C3B8A6` | Secondary text | **9.8:1** |
| `rule` | `#776B5F` | Hairlines | **3.6:1** (component) |
| `pandan` | `#74D3AA` | Visited, primary action | **10.5:1** |
| `bay` | `#8CC6EC` | Wishlist | **10.3:1** |
| `onPandan` / `onBay` | `#0D1513` | Text on a filled control | **≥ 8.2:1** on the fill |

**Pandan green and bay blue** replace the original lacquer red and jade (19 Aug 2026): the warm
scheme read as dusty rather than appetising, and the app is about fresh food. Green for a place you
have eaten at, blue for water you have not crossed yet. They are drawn from the food and the coast
rather than picked at
random, which keeps the palette specific to the market without resorting to flag colours.

## Components

### Map pin — the signature element
```
   visited                wishlist
  ┌ ─ ─ ─ ─ ┐            ┌ ─ ─ ─ ─ ┐
  │ ▓▓▓▓▓▓▓ │            │    ✦    │
  │ ▓photo▓ │            │         │
  │ ▓▓▓▓▓▓▓ │            └ ─ ─ ─ ─ ┘
  └ ─ ─ ─ ─ ┘         outlined, bay, dashed
 scalloped edge,
 pandan border
```
- **Visited:** the photograph, in a scalloped "stamp" frame with a pandan border.
- **Wishlist:** an empty stamp outline in bay with a bookmark glyph — **shape and fill differ,
  not only colour**, satisfying NFR-6.3 for colour-blind users.
- **Cluster:** stacked stamp edges with a count in the corner, like layered postcards.

### Bottom sheet
The only navigation surface. Three detents: peek (a handle plus one row), half (the list), and
full (place detail). The map is never fully covered at the peek and half detents.

### Cards
`paperRaised`, 1 pt `rule` border, 12 pt corner radius, and a very soft shadow. No heavy
drop shadows — the language is printed paper, not floating glass.

### Chrome is iconographic, and it floats on the map
The three actions — add a meal, save a place, near me — are circular icon buttons on the map
itself, stacked above the sheet's peek detent, with the camera largest and in pandan. Labels in
two languages of very different lengths made a labelled row wrap or clip on the smallest iPhone,
and the three glyphs (camera, bookmark, location) are unambiguous. Every one carries a VoiceOver
label, so nothing is lost to a screen reader.

Putting them on the map rather than in the sheet means the sheet's smallest detent only has to
clear the search field, and the actions stay reachable at every detent — including when the
sheet is pulled up over them, where they are simply out of the way.

Two things this cost, both worth recording:

- The map cannot present a sheet while it is presenting the bottom sheet, so the action's
  destination is presented *from the sheet*, driven by `MapViewModel.action`.
- `presentationBackgroundInteraction` must name a detent the sheet actually has. It read
  `upThrough: .medium` while the detents were `.height` and `.fraction`, which silently
  disabled background interaction and left the floating buttons unreachable behind the sheet.

### The sheet leads with a search field
At the peek detent the sheet is a search input and the first row or two of results.

### Opening a place moves the map to its pin
Tapping a place centres the map on it and lifts the sheet to its middle detent — not to full
height, because the point is to see the pin the map just moved to (FR-4.6). This replaces what
would otherwise be a "show on map" button: the map follows the reading, so nothing has to be
asked for.

The region's centre is set *south* of the place by 30% of the visible span, which lifts the pin
into the band above the sheet. Centring it geometrically put the pin behind the sheet — visible
only as a sliver, which is how the bias was found.

### Meal pins carry the photograph
A visited place's pin is its own food photograph in a perforated stamp frame, with a badge
counting repeat visits; a wishlist pin is a dashed bay frame around a bookmark. This is the
signature element of the whole design, and it only reads as one because the pin is where the
photo goes.

### Spacing is a scale, not a decision per view
`Theme.Space` is a 4 pt scale — 4, 8, 12, 16, 24, 32 — with `screenMargin` (16) for every screen
edge and `contentInset` (12) inside cards and fields, one step tighter so nested edges do not
read as doubled. Before it, views carried 6, 9, 10, 14, 18, 22 and 26 pt paddings chosen one at
a time, and nothing lined up across screens.

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

## The map has no header, and its pins are the way in (FR-3.10)

The wordmark and the All / Been here / Want to try segments used to sit above the map, costing
about 110 pt of the thing the app is named after. Both moved: the filter is the first row of the
sheet, next to the search field it belongs with, and the title is gone — a map-first app does not
need to introduce itself on every launch.

That makes pins the map's only controls, so tapping one has to work. It must go through MapKit's
own selection — `Map(position:selection:)` with `.tag()` on each `Annotation` — not a `Button` or
a tap gesture inside the annotation. With the bottom sheet presented, SwiftUI content hosted
inside the map never receives the touch, however correct its accessibility traits; only the map's
native hit testing does. A single-place pin opens that place; a cluster opens a sheet listing its
places, and choosing one opens it.

The corollary for the journeys: while the sheet is raised, a pin is *present* in the accessibility
tree but sits underneath the sheet, so a tap lands on the sheet instead. TC-2-11 drags the sheet
back to its peek first — the same gesture a reader makes.

## Photographs fill the width they are given, at one ratio

Every photograph in the app is presented the same way: it fills the width of its container at
`Theme.photoAspect` (3:2), cropped from the centre, with rounded corners. A meal card used to
show a 132 pt square inside a full-width card, which left two thirds of the card empty and read
as a photograph that had failed to load rather than as a layout. The review step square-cropped
the shot the user had just taken, cutting the edges off the dish.

Three details this decision depends on:

- **The ratio goes on a clear container, not on the image.** `Color.clear.aspectRatio(_:.fit)`
  with the image as an `.overlay` and a `clipShape` around both. Setting a frame *and* an aspect
  ratio on the image itself makes the two rules fight, and what loses is the crop.
- **A hero reads from the full-size file, not the thumbnail.** Thumbnails are 240 px squares for
  map pins; upscaled to a card's width they are visibly soft, which the old square tile hid.
  `PhotoImageLoader` therefore keeps a second, small cache for full-size images, bounded by pixel
  cost rather than count.
- **Extra photographs are a strip below the hero**, 76 pt squares, not equal peers. A meal has one
  subject and some supporting shots.

3:2 rather than 4:3 because the card lives in a bottom sheet: at 4:3 the dish name and the stars
fell below the fold at the reading detent.

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
- Pin selection is MapKit's, so a pin's accessibility label is applied to the annotation content
  rather than to a control wrapping it.
- Camera permission is now a real dependency of the primary flow; refusal is handled inside the
  camera screen, which offers the photo library instead rather than dead-ending.
