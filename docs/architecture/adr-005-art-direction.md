# ADR-005 — Art direction: a printed journal

**Status:** accepted
**Supersedes nothing.** Extends ADR-003, which set the travel-journal/editorial direction and the
palette; this decides what the app is *made of*.
**Context:** the 19 Aug 2026 design review (`docs/design/review-2026-08-19.md`) found the app
reading as competent stock SwiftUI: Apple's cartography and POI pins, Apple's glyphs, Apple's
segmented control, a dark mode with no identity.

## Decision

The app is a **printed journal**: pages of paper you can almost feel, chrome and ornament printed
in two or three inks that do not quite register, and photographs left completely alone.

Two influences, deliberately combined:

- **The physical journal** gives the structure — paper, torn and perforated edges, stamps, tape,
  cards that sit a degree or two off square, pressed-in shadows, handwriting for the user's own
  words.
- **Risograph printing** gives the ink — a small number of spot colours, a visible offset between
  layers, halftone rather than smooth gradient, grain everywhere.

## The rules that keep it usable

1. **Never tint a photograph.** The food is the content. Every printing effect stops at the chrome,
   the ornament and the empty states. This is what makes a riso influence survivable in an app
   whose subject is photographs.
2. **Never texture behind body text.** Grain lives on page grounds and behind display type, not
   under a paragraph or a form field.
3. **Contrast is not negotiable.** Every ink pairing is registered in `Palette.renderedPairings`
   and asserted by TC-N-07; art that fails AA does not ship.
4. **Restraint where the work happens.** The confirm form, the search list and the camera stay
   plain. Art belongs on the map, the pins, the covers, the empty states, the passport and the
   transitions.
5. **Texture is procedural, never an asset.** One cached noise tile and drawn shapes: no image
   bloat, dark-mode variants for free, and it scales with Dynamic Type.

## The inks

Two accents already exist — lacquer red for places you have been, jade for places you want to try.
The art direction adds **indigo** as the printing ink: the second layer in a misregistration, the
colour of ornaments, rules and stamp frames. Three inks is a zine; five is a mess.

## Dark mode is a night market

Not a neutral inversion. A warm ink-brown ground rather than grey-black, lacquer and jade pushed
to neon, indigo deepened, photographs given a faint bloom so they read as lit rather than as
cut-outs on black.

## Primitives, not screens

The direction ships as design-system pieces, so no screen invents its own version:

| Piece | What it does |
|---|---|
| `PaperTexture` | One cached procedural noise tile, tiled under page grounds |
| `InkLayer` | Reprints a shape 1.5 pt off in a second ink at low alpha — the misregistration |
| `FoodMark` | The drawn glyph set that retires SF Symbols from primary chrome |
| `StampShape` family | Perforated stamp (visited), torn ticket (wishlist), deterministic tilt per place |
| Paper motion | Springs tuned to feel like card and pressure, a stamp "press" on tap |

## Type

The display serif stays. Labels become letterspaced small caps; dates are set in a stamped mono.
Any face used for the user's own notes must carry **full Vietnamese diacritics** — that is a hard
filter on candidates, ahead of taste, and it is why the hand style is a decision deferred until a
licensed face is chosen. Until then notes stay in the italic display serif.

## Consequences

- `FoodMapDesign` gains the indigo ink and its pairings, so contrast stays machine-checked.
- The map is no longer Apple's: food points of interest are excluded so the only food on the map is
  the user's, and the cartography is warmed by a paper wash to sit in the same world as the sheet.
- SF Symbols remain acceptable in secondary places (menus, form rows) where drawing our own would
  cost more than it returns.
- Reduce Motion turns the paper physics into simple fades; Reduce Transparency drops the washes.
