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
picks the ink also decides how carefully the stamp was printed, so a one-star place and a five-star
place are told apart at pin size with no text and no colour vision.

The ramp is deliberately narrow. An earlier version reached for the whole vocabulary of a bad print
— broken rules, smudged impressions, a second ink missing by three points — and the result was
mess, not craft: a one-star stamp read as a rendering fault, and a five-star one as a badge. What is
left is the smallest set of moves that still orders five steps, and all of them are quiet.

| | One star | Five stars |
|---|---|---|
| Stuck down | A little off square | Square |
| The rule around it | Fine and pale | Full weight and solid |
| Inside it | Nothing | One hairline, set in from the first |

Everything else — the perforated edge, the white paper margin, the misregistration — is the same on
every stamp, because those are what make it a stamp rather than what make it a good one.

The ramp is one number, and every property above is read off it, so the steps stay ordered by
construction: no dimension may improve as the score falls (TC-N-22).

Two rules constrain it. **An unrated place is not a bad place.** No score at all prints at a plain,
competent middle, never at the bottom of the ramp — the same rule `RatingMood` follows for ink.
And **the ramp is decoration over an existing signal, never the only carrier of one**: the score
stays in the text, the stars and the VoiceOver label (NFR-6.3).

## Type

The display serif stays. Labels become letterspaced small caps; dates are set in a stamped mono.
Any face used for the user's own notes must carry **full Vietnamese diacritics** — that is a hard
filter on candidates, ahead of taste, and it is why the hand style is a decision deferred until a
licensed face is chosen. Until then notes stay in the italic display serif.

## Consequences

- `FoodMapDesign` gains the indigo ink and its pairings, so contrast stays machine-checked.
- The map stays Apple's, unwashed: only the food points of interest are excluded, so the only food
  on it is the user's. The cartography is where the app is read, and it is left legible; the
  direction is carried by everything drawn *on* the page instead (ADR-006).
- SF Symbols remain acceptable in secondary places (menus, form rows) where drawing our own would
  cost more than it returns.
- Reduce Motion turns the paper physics into simple fades; Reduce Transparency drops the washes.
