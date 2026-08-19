# ADR-004 — Which position we trust, and when

**Status:** accepted
**Context:** UC-1 / 1a and 3, FR-1.3, FR-1.11 … FR-1.17

## Decision

A meal's coordinate is decided in this order, and each step exists because the one before it can
be wrong:

1. **The photograph's own GPS wins.** A dish photographed at lunch and logged that evening at home
   must pin the restaurant, not the sofa.
2. **Time and coordinate come from the same photograph** — the earliest one that carries a
   coordinate. Reading the time from one shot and the place from another can date tonight's meal
   to yesterday's lunch (FR-1.16).
3. **EXIF times are wall clock, not UTC.** `DateTimeOriginal` carries no zone. Where EXIF 2.31's
   `OffsetTimeOriginal` is present it is the truth; otherwise the device's own zone is used, which
   is the convention the Photos app follows. Reading it as UTC moved every Vietnamese lunch to
   dinner (FR-1.3).
4. **0°, 0° is not a place.** Cameras write it in place of a missing fix, so it counts as absent
   (FR-1.17).
5. **Otherwise the device fix, judged before it is used.** Accuracy travels with the coordinate,
   because a coordinate alone cannot be judged.

## What makes a device fix usable

- **Accuracy no coarser than the preselection radius (120 m), and not negative.**
  `desiredAccuracy` is a request, not a promise: a cell-tower fix good to 1.5 km will arrive and be
  offered, and Core Location signals an invalid fix with a negative accuracy. A fix looser than the
  radius cannot tell two neighbouring shops apart, so it preselects nothing rather than guessing —
  the user would rather search than un-pick a wrong restaurant (FR-1.13). The gate is applied
  twice: at the adapter, which never caches a coarse fix, and in the use case, which declines to
  guess from one.
- **No older than 60 s, including on timeout.** Long enough that walking in from the street reuses
  the fix, short enough that the last restaurant's fix never does. The timeout path applies the
  same rule, so a stale fix cannot win by nothing else arriving (FR-1.14).
- **An undecided permission is asked for and awaited.** The first meal is logged seconds after the
  first launch, with the permission dialog possibly still open; reporting "no location" to someone
  about to say yes is a self-inflicted wound (FR-1.15). A denial ends the wait at once.

None of this ever throws. A refused permission, a dead network, a hopeless fix: all of them mean
"no coordinate", the place is left unset, and the meal still saves (FR-1.6, FR-1.12).

## Structure

The rules live in `LocationFixResolver`, an actor in `FoodMapData`, and `CoreLocationAdapter` is a
thin translation of Core Location's vocabulary into it. Two reasons:

- **Testability.** The resolver takes its authorisation, its fix request and its clock as closures,
  so every rule above is a fast unit test with no device, no simulator and no waiting
  (TC-1-22 … TC-1-24). The adapter is left with nothing worth testing.
- **Concurrency.** The fix arrives on the delegate's queue and is read from whichever task asked
  for it. The previous implementation guarded only its list of waiters with a lock and left the
  cached fix racing, under an `@unchecked Sendable` that hid it. Actor isolation covers both.

## Consequences

- `LocationPort` returns a `LocationFix` (coordinate plus accuracy), not a bare coordinate.
  Callers that only need a point — "near me" distances, the user's dot — use the
  `currentCoordinate()` extension and are unaffected by the accuracy gate, which is correct: a
  coarse fix still sorts a list usefully, it just cannot choose a restaurant.
- Distances are Haversine on a 6,371 km sphere, accurate to well under a metre at city scale.
- The 120 m radius has one definition, `SuggestMealPlaceUseCase.radius`, which the accuracy
  ceiling is derived from rather than repeated.
