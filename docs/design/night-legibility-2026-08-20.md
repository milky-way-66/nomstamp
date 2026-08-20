# Design note, 20 August — the night market was hard to read

The complaint was plain: at night the app is hard to look at and hard to see. Measuring it rather
than arguing about it turned up three separate faults, none of which the existing contrast suite
could see, because every one of them lives in the gap between "a pairing passes WCAG" and "a page
is comfortable to read in the dark".

## 1. The page and the card were the same colour

`paper` was `#0A1210` and `paperRaised` was `#14201C`: **1.13:1**. That is below the threshold where
two greys read as two surfaces at all. Every card, sheet and field in the app was therefore held
together entirely by its one-point contour — and the contour is drawn in the body ink, so what a
reader saw at night was a page of thin outlines floating on a single black field, with no sense of
one thing sitting on top of another.

The night grounds are now `#111A17` and `#243230`, **1.33:1**. Still a dark page — this is a night
market, not a grey app — but a card is now a card before its outline is read.

That one change is what forces the rest of this note. Every ink in the app is checked against
*both* grounds, so lifting the raised ground by a third means every ink drawn on it has to come up
with it or fall through the AAA floor it used to clear.

## 2. Near-black paper with near-white ink is a glare, not a contrast

Body ink was `#EDF4F0` on `#0A1210`: **16.98:1**. Nothing is wrong with that number, and that is
the point — the pairing passes AAA nearly two and a half times over, and it is exactly what makes a
phone unpleasant to read in a dark room. A near-white field of type on a near-black ground blooms
at the edges of the letters.

Body ink is now `#E6EFEA` on the lifted page: **15.12:1** on the page, **11.37:1** on a card. Still
comfortably above the AAA floor this app holds itself to, with the top end of the range taken off.

The whole night palette moves the same way: the page comes up, the brightest ink comes down
slightly, and the working range gets narrower at both ends rather than being stretched to the
maximum the screen can produce.

## 3. The one colour that carries no information had all of it taken away

Stamp papers are the coloured band around each photograph — the thing that makes a page of pins
look like a page of stamps rather than a page of white rectangles (ADR-005). At night they ran from
**2.30:1** (lilac) to **3.91:1** (butter) against the page, and *below 3:1 for five of the seven*
against a card. They were, in practice, invisible after dark: the album lost the one decorative
device that makes it an album.

They were never contrast-checked, because they are decoration and decoration carries no
information — but "carries no information" is not the same as "may be invisible". If the app is
going to draw it, the reader has to be able to see it. All seven now clear the component floor
(3:1) against **both** night grounds, which is the same level the app already holds its separators
and pin outlines to.

## What is now guaranteed

Three new assertions, all of them cheap and all of them in `FoodMapDesign` where they run in
milliseconds:

- The night page and a night card must separate as two surfaces (TC-N-28).
- No ink the app draws may exceed a comfort ceiling against the night page (TC-N-28).
- Every stamp paper must clear the component floor on both night grounds (TC-N-28).

All three are night rules, and deliberately not rules for both appearances. On a bright page a
card is separated by its shadow as well as its ground, and the stamp papers are pale pastels told
apart by hue — a luminance floor applied there would force the whole set dark and take the album's
colour away in the appearance where it already works. Chroma is the first thing the eye loses as
luminance falls, which is why the same band has to carry a difference in *light* at night and does
not in daylight. The light appearance is untouched by all of this.

The friend plate, the rating ramp and the five skins were all re-solved against the new card
ground. Each ink was lifted in HSL — hue and saturation held exactly, lightness raised by the
smallest step that clears the floor — so the plate keeps its hue separation, the ramp keeps its
order, and no colour in the app changed identity. Only the night values moved; the light appearance
is untouched.
