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

Two accents already exist — pandan green for places you have been, bay blue for places you want to try.
The art direction adds **indigo** as the printing ink: the second layer in a misregistration, the
colour of ornaments, rules and stamp frames. Three inks is a zine; five is a mess.

## Dark mode is a night market

Not a neutral inversion. A deep green-black ground rather than grey-black, pandan and bay pushed
to neon, indigo deepened, photographs given a faint bloom so they read as lit rather than as
cut-outs on black.

## Primitives, not screens

The direction ships as design-system pieces, so no screen invents its own version:

| Piece | What it does |
|---|---|
| `PaperTexture` | One cached procedural noise tile, tiled under page grounds |
| `InkLayer` | Reprints a shape 1.5 pt off in a second ink at low alpha — the misregistration |
| `FoodMark` | The drawn glyph set that retires SF Symbols from primary chrome |
| `RatingMood` | The ink ramp a score paints, from slate at one star to leaf green at five |
| `StampPress` | The *quality* ramp a score prints at, from a bad impression at one star to a perfect one at five |
| `DeckleEdge` | A deterministic torn-paper edge, used where a photograph meets the page |
| `InkTabs` | Drawn filter tabs — small caps over a brushed underline — in place of the stock segmented control |
| `StampShape` family | Perforated stamp (visited), torn ticket (wishlist), deterministic tilt per place |
| Paper motion | Springs tuned to feel like card and pressure, a stamp "press" on tap |

## A score is printed, not annotated

A stamp does not report its rating with a number beside it. It *is* the rating: the same score that
picks the ink also decides how well the stamp was printed, so a one-star place and a five-star place
are told apart across a room, at pin size, with no text and no colour vision.

| | One star | Five stars |
|---|---|---|
| Stuck down | Crooked, well off square | Square, placed with care |
| Registration | The second ink misses by a lot | Almost perfect |
| The rule around it | Thin, faded, broken | Full weight, solid, with an inner hairline and corner ticks |
| The impression | Soft and smudged, as if pressed with a rocking hand | Crisp |
| How it sits | Flat on the page | Lifted, with its own shadow |

The ramp is one number — how good the impression is — and every property above is read off it, so
the steps stay ordered by construction: no dimension may improve as the score falls (TC-N-22).

Two rules constrain it. **An unrated place is not a bad place.** No score at all prints at a plain,
competent middle, never at the bottom of the ramp — the same rule `RatingMood` follows for ink.
And **the ramp is decoration over an existing signal, never the only carrier of one**: the score
stays in the text, the stars and the VoiceOver label, because a smudge is not something a reader
can be asked to measure (NFR-6.3).

## Type

The display serif stays. Labels become letterspaced small caps; dates are set in a stamped mono.
Any face used for the user's own notes must carry **full Vietnamese diacritics** — that is a hard
filter on candidates, ahead of taste, and it is why the hand style is a decision deferred until a
licensed face is chosen. Until then notes stay in the italic display serif.

## Consequences

- `FoodMapDesign` gains the indigo ink and its pairings, so contrast stays machine-checked.
- The map is no longer Apple's: food points of interest are excluded so the only food on the map is
  the user's, and the cartography is re-inked in the skin's colour — its own light left intact —
  to sit in the same world as the sheet (ADR-006).
- SF Symbols remain acceptable in secondary places (menus, form rows) where drawing our own would
  cost more than it returns.
- Reduce Motion turns the paper physics into simple fades; Reduce Transparency drops the washes.
- Rule 1 costs something on the map: the wash is drawn over the map view, and the pins are hosted
  inside it, so the ink lands on the photographs too unless it is stopped. It is stopped by masking
  the wash with a soft hole at each stamp — which is also why the day map may be printed as strongly
  as it likes without the meals turning the colour of the skin.
