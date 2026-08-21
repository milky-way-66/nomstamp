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

---

## Amendment, 21 August — the gate was applied to everyone

A reader reported that the app cannot find them, and does not show them on the map, with location
permission granted. Three separate faults, and the first is this document describing behaviour the
code does not have.

### 1. The accuracy gate escaped its purpose

The Consequences section above says, of callers that only need a point:

> …use the `currentCoordinate()` extension and are **unaffected by the accuracy gate**, which is
> correct: a coarse fix still sorts a list usefully, it just cannot choose a restaurant.

`LocationPort.currentCoordinate()`'s own comment says the same — *where a coarse fix is still
useful*. Neither is true. `currentCoordinate()` calls `currentFix()`, and the gate lives inside
`LocationFixResolver.received()`, which **filters coarse reports out before anything is cached or
returned**. By the time a caller could exercise judgement, there is nothing left to judge.

So a 150 m fix — an ordinary indoor fix, in an ordinary restaurant, which is where this app is used
— produces *no location at all*: not for Near Me, not for the appearance's daylight lookup, not for
the map. The 120 m ceiling exists for one question, *which restaurant am I in* (FR-1.13), and it was
silently answering three.

**The gate moves to the caller.** `LocationFixResolver` reports the best fix it has, with its
accuracy attached, and stops discarding. `SuggestMealPlaceUseCase` keeps the 120 m rule, because
that rule is *its* rule. Near Me, the appearance and the map take what they are given: a 300 m fix
sorts a list of saved places perfectly well, and a map centred 300 m out is a map the reader can
see themselves on.

This is what ADR-004 always said. It is now also what happens.

### 2. One shot, and the shot was thrown away

`CoreLocationAdapter` asks with `requestLocation()`, which delivers **once** and stops. Combined
with fault 1, the sequence in a restaurant is:

1. `requestLocation()`.
2. Core Location delivers its first fix — commonly 100–500 m, because a cold GPS indoors starts
   coarse and tightens over the next few seconds.
3. `received()` filters it out, returns early, and **resumes nobody**.
4. Nothing asks again, because `requestLocation()` has already finished.
5. The caller waits out the full 6 s timeout and is told there is no location.

The fix that would have arrived at second three, good to 30 m, is never requested. The reader sees
a spinner, then nothing, with permission granted and GPS working.

**The adapter switches to `startUpdatingLocation()` for the duration of a request**, and stops when
the request is satisfied or times out. That is what lets a fix *improve*: the resolver keeps the
best one seen so far, resumes waiters as soon as it holds something usable, and continues to accept
a better one until it stops. One-shot `requestLocation()` is the wrong API for "tell me where I am
as well as you can in the next few seconds".

### 3. `kCLErrorLocationUnknown` is not an answer

`didFailWithError` currently ends the wait. Apple documents `kCLErrorLocationUnknown` as transient —
the framework is still trying. Ending the wait on it converts a delay into a failure. Only
`kCLErrorDenied` ends the wait; everything else lets the timeout do its job.

### 4. The map has no way back to the reader

Distinct from the three above, and the half of the complaint about *showing* position. `MapScreen`
opens with `camera = .userLocation(fallback: Hanoi)`, which is right. But opening any place
reassigns `camera = .region(...)` so the pin clears the sheet — and **nothing ever assigns
`.userLocation` again.** After the first place the reader opens, the map has no relationship to
where they are for the rest of the session.

The *near me* button does not do it either: it opens the Near Me sheet, which is a list.

**A recentre control is added** — MapKit's own `MapUserLocationButton`, in the existing action
cluster so it inherits the drawn chrome (ADR-005) rather than arriving as stock. It is the one
control on the map that answers *where am I*, and the app has been asking readers to answer it
themselves.

### What this changes about the rules

The "what makes a device fix usable" section above is now split in two, because it was conflating a
property of the *fix* with a property of the *question*:

| | Rule | Whose rule |
|---|---|---|
| Freshness | no older than 60 s | the **fix's** — a stale fix is wrong for everyone |
| Validity | accuracy not negative | the **fix's** — Core Location's own invalid marker |
| Precision | no coarser than 120 m | the **caller's** — only place preselection needs it |

The first two stay in the resolver. The third belongs to `SuggestMealPlaceUseCase`, which is where
FR-1.13 was always pointing.
