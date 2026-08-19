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
Contrast ratios below were computed, not estimated. All pass WCAG AA (NFR-6.4); the lowest
is 5.21:1.

### Light — "paper"
| Token | Hex | Use | Contrast on paper |
|---|---|---|---|
| `paper` | `#F5EFE3` | App background | — |
| `paperRaised` | `#FDFAF3` | Cards, sheets | — |
| `ink` | `#2A2521` | Primary text | **13.24:1** |
| `inkSecondary` | `#6B6259` | Secondary text | **5.21:1** |
| `rule` | `#DCD2C0` | Hairlines, stamp perforations | — |
| `lacquer` | `#A8402F` | Visited places, primary action | **5.33:1** |
| `jade` | `#2F6152` | Wishlist places | **6.21:1** |

### Dark — "night"
| Token | Hex | Use | Contrast on night |
|---|---|---|---|
| `paper` | `#1A1714` | Background | — |
| `paperRaised` | `#241F1B` | Cards, sheets | — |
| `ink` | `#F0E9DC` | Primary text | **14.78:1** |
| `inkSecondary` | `#A79C8D` | Secondary text | **6.62:1** |
| `rule` | `#3A332C` | Hairlines | — |
| `lacquer` | `#D97A66` | Visited, primary action | **5.89:1** |
| `jade` | `#6FAF97` | Wishlist | **7.02:1** |

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

## Motion
Restrained: 200–250 ms ease-out for sheet and pin transitions. One signature moment — a newly
saved meal's stamp settles onto the map with a slight scale-down, like a stamp being pressed.
Everything honours **Reduce Motion**.

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
