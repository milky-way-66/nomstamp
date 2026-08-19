# ADR-001 — Map provider and place search

**Date:** 2026-08-19 · **Status:** proposed · **Context:** iPhone-only app, local-only data,
no backend, primary market **Vietnam**.

## The question
How do we display a map, and how does a user find the restaurant they are sitting in (UC-1)
or the one they heard about (UC-4), given Vietnam-specific data-quality risk?

## Evidence gathered
Measured directly against Apple's live APIs and OpenStreetMap on 2026-08-19.

**Named search (`MKLocalSearch`, natural language) — good**

| Query | Near | Result |
|---|---|---|
| `Phở Thìn` | Hanoi | 23 hits, correct Lò Đúc branch |
| `Bún chả Hương Liên` | Hanoi | exact hit, correct street |
| `Bánh mì` | HCMC D1 | 25 hits incl. Bánh Mì Như Lan |
| `Phở` | Hanoi Old Quarter | 25 hits incl. Phở 10 Lý Quốc Sư |

**Nearby POI search (`MKLocalPointsOfInterestRequest` + category filter) — good**

| Location | Food places within 500m |
|---|---|
| Hanoi Old Quarter | 50 (API cap) |
| HCMC District 1 | 49 |
| Da Nang | 50 (API cap) |
| Hoi An | 50 (API cap) |

Results are real local businesses (*Quán Cơm Niêu Minh Anh*, *Nhà Hàng Đặng Văn Sáo*),
not just international chains.

**Generic Vietnamese category words in free-text search — BROKEN**

| Query | Near | Result |
|---|---|---|
| `cà phê` | HCMC D1 | 1 result, ~1,100 km away near Hanoi |
| `quán ăn` | Da Nang | 1 result, ~700 km away in the Mekong Delta |

The region bias is ignored for these terms. **Consequence: never issue category words as
free text.** Use `MKPointOfInterestFilter` categories, which tested well.

**OpenStreetMap comparison** — 300 food nodes (211 named) within the same 500m of Hanoi Old
Quarter, versus Apple's 50-result cap. OSM is denser, but Overpass is not intended for
production client traffic and has no iOS SDK.

## Decision
1. **Map: MapKit / SwiftUI `Map`.** No API key, no billing, no backend, native Vietnamese
   label rendering, and it ships with the OS.
2. **Nearby search: `MKLocalPointsOfInterestRequest`** with a food category filter — the
   zero-typing path for UC-1.
3. **Named search: `MKLocalSearch`** with a region hint — for UC-4.
4. **Manual pin drop with a typed name is a first-class path, not a fallback.**

## Why (4) matters most in Vietnam
Much of the food worth remembering — *quán vỉa hè*, a *bánh mì* cart, a stall with no
signboard — is in **no commercial database at all**. Any design that assumes the place is
findable will fail exactly where this app should be strongest. Because the user is standing
there with GPS running, the app already knows the coordinates precisely; only the name is
missing, and the user can type it in five seconds.

So the search hierarchy is:
```
1. Nearby POI list      → one tap, no typing        (works ~always in VN cities)
2. Search by name       → for places heard about    (good for named restaurants)
3. Use my exact GPS spot → type the name yourself   (always works, incl. street food)
```

## Rejected alternatives
- **Google Places API** — best Vietnam coverage, but requires an API key and billing, and its
  terms require rendering Places results on a Google map, which forces Google Maps SDK for
  display too. Rejected as incompatible with "no backend, no keys, no cost".
- **OpenStreetMap + Overpass** — denser data and free, but the public Overpass endpoint is not
  for production traffic and would need our own server to be viable, which contradicts the
  no-backend constraint. Reconsider if Apple's coverage proves insufficient in practice.
- **MapLibre + OSM tiles** — needs a tile host; same backend objection.

## Consequences and open risks
- **Map tiles and place search need the internet.** "Local-only" refers to *our data*: photos
  and meals never leave the device and there is no server. Viewing the map in a new city still
  requires connectivity. Logging a meal offline works fully (GPS + manual name); only the
  nearby-suggestions list degrades.
- **POI coordinate precision must be verified on-device.** In the command-line test nearly all
  POI results reported 3–5 m distance, which is implausible and suggests degraded precision
  outside a real app context. To be confirmed in the simulator.
- Apple caps nearby results around 50; acceptable, since the user picks from the closest few.
