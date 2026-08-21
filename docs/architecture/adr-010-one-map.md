# ADR-010 — One map: a friend's places are places

**Status:** accepted. **Amends ADR-009**, which stays intact as the record of the transport, the
ceremony and the sealed zone — none of which changes here. What changes is what the map *draws*.
**Supersedes ADR-009's *A friend's ink* section** in full.
**Amends FR-11.2, FR-12.2, FR-12.4, FR-12.5, FR-12.5a, FR-12.9 and NFR-6.3** in the SRS.

## Context: the map was answering a question nobody asked

ADR-009 built a careful visual grammar for friends. The cut answers *mine or theirs*: the reader's
own stamps keep a solid edge, a friend's carry a perforated one. The ink answers *which friend*,
from a fixed plate of eight. A place both have stamped becomes one pin with a countersignature and
a numeral for the rest.

It is coherent, it is well-argued, and in front of a map it reads as noise. Three signals — cut,
hue, badge — all encoding provenance, on a mark small enough that a restaurant is a coloured
lozenge. The reader looking at their map is not asking *whose is this*. They are asking *where is
worth eating*. Provenance is a second question, asked about one place at a time, and answering it
on every pin at all times costs the map its calm to no purpose.

The eight inks made this worse rather than better. Eight hues, none of which may collide with
`visitedInk` or `wishlistInk`, all clearing AAA over paper in light and dark, on a mark a few
points across — and at the end of it the reader still cannot tell rust from gold without learning
a legend. FR-12.5a had already conceded that friend-versus-friend rests on colour alone. This
decision stops paying for a distinction that was never going to carry.

## Decision

**A friend's place is drawn exactly as the reader's own.** Same pin, same cut, same ink, same
wishlist bookmark. No perforated edge, no per-friend hue, no countersign badge, no numeral.

Three things follow.

**1. A friend's wishlist travels too.** If the map is one map, then a friend's *want to try* is as
useful as their *been there* — arguably more so, since it is a recommendation rather than a
memory. `SharedStamp` gains a `kind`, and the fields that only make sense for a visit — average
rating, visit count, latest dish, last visited month — become optional, because a place nobody has
been to has none of them. FR-11.1 is untouched: nothing is shared that the reader did not
explicitly share, and a wishlist place is no different.

**2. Provenance moves to detail, entirely.** Tapping a place is how a reader learns whose it is.
The place page already names every friend who stamped it, in ink order (FR-12.8), and that becomes
the *only* place attribution is drawn rather than a fuller version of what the pin implied. The
inks survive there and in the filter, where there is room for a name beside them and where the
question being asked really is *which friend*.

**3. The filter carries the weight the pin used to.** Once every pin looks alike, "show me only
Lan's" and "show me only wishlists" stop being conveniences and become the way the map is read at
all. Both are required, and both must be reachable together — Lan's wishlist is a more natural
question than either half alone.

## What this costs, stated plainly

**The reader can no longer tell their own places from their friends' at a glance.** That is not a
side effect; it is the decision. A place Lan raved about and a meal the reader remembers are the
same mark until one of them is tapped.

This is a real loss and it should be recorded as one. Two things make it acceptable. The map is
already filtered by a switch the reader operates — the friends layer is off by default (FR-12.1),
so an unmixed map of one's own places is always one tap away. And the filter makes the separation
available on demand rather than permanent, which is the right default for a question asked
occasionally.

If it proves wrong in use, the cheapest reversal is *not* to bring back the cut and the plate: it
is to give the filter a *mine only* position, which is one control and no new visual language.

## What is not changed

The transport, the ceremony, the proximity gate, the sealed zone, the eight-friend cap, the
per-place record and everything ADR-009 says about what may leave the device. `FriendInk` keeps its
plate of eight and its deterministic assignment from the public key — it simply stops being drawn
on the map and keeps working where a friend is named.

VoiceOver keeps everything FR-12.10 gave it. A pin that no longer says whose it is *visually* must
still say so aloud, because a reader using VoiceOver has no "tap to see detail" glance — the label
is their glance. This is the one place the old and new designs agree completely.
