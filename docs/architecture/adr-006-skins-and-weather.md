# ADR-006 — The app dresses for the day

**Status:** accepted, 19 Aug 2026
**Supersedes nothing.** Extends [ADR-003](adr-003-ui-design.md) and [ADR-005](adr-005-art-direction.md).

## Context

The printed-journal direction gave the app one set of inks. A journal kept over months is not
printed in one ink: the page you write on a wet afternoon does not look like the one you write in
the sun. The app should feel like the day it is being used on — different colours, a different
light, without becoming a different app or losing its contrast guarantees.

## Decision

**A skin is a set of inks, not a new design.** Paper, type, grain, stamps, tearing and layout never
change. A skin decides:

| What | Why it is in the skin |
|---|---|
| The visited ink | The accent doing most of the talking: pins, actions, ratings |
| The wishlist ink | Its counterpoint, always a different hue family |
| The printing ink | The misregistration under stamps and chrome |
| The map wash | The hue the cartography is printed in |

Five skins, named for things you eat or drink or sit next to:

| Skin | Family | Feels like |
|---|---|---|
| `pandan` | green | fresh, the default |
| `bay` | blue | water, rain, cold |
| `tamarind` | orange | sun, heat, late afternoon |
| `sim` | purple | dusk, fog, the hour before a night market |
| `lotus` | pink | warm evening, festival |

**What chooses the skin is the sky, and the rule is in the domain.** `ChooseAppearanceUseCase` takes
a weather condition, whether it is daylight, and the date, and returns a skin, an effect and whether
the app should be dark. It is pure, so the rule is a unit test and not a screenshot:

| Sky | Skin | Effect |
|---|---|---|
| Clear, day | `tamarind` | `bloom` |
| Clear, night | `sim` | `lanterns` |
| Cloudy | `pandan` | `haze` |
| Fog | `sim` | `haze` |
| Rain or storm | `bay` | `rain` |
| Snow | `bay` | `haze` |
| Unknown | rotates daily | none |

**Dark follows the sun, not the system.** Daylight means the light appearance, night means the dark
one — the night market. The system setting is overridden because "night" is a fact about where the
user is standing, and the app already knows it from the same weather reading.

**With no weather, the skin rotates by day.** No reading (no permission, no network, no entitlement)
means the skin comes from the date: the same skin all day, a different one tomorrow. Random per
launch was rejected — an app that changes colour while you look at it reads as broken, not alive.

**Effects are drawn, never photographed.** Rain is ruled ink streaks, haze is a paper wash,
`bloom` a warm halo, `lanterns` a scatter of specks. They sit over the map only — never over a
photograph, a form or a paragraph (ADR-005 rules 1 and 2) — and they are suppressed under Reduce
Transparency.

**Contrast is checked per skin.** `Palette.renderedPairings(for:)` is a function of the skin, and
TC-N-18 walks every skin in both appearances. A skin that cannot meet the levels is not a skin.

**Weather comes from WeatherKit, behind a port.** `WeatherPort` lives in the domain; the adapter in
`FoodMapData` wraps WeatherKit and returns nil for anything it cannot answer — no permission, no
entitlement, no network, a throw. Nil is not an error state in the interface: it is the rotation.

## Consequences

- Colour tokens are named for their role (`visitedInk`, `wishlistInk`), not for a hue. A token
  called `pandan` painting tamarind orange would be a lie.
- The weather reading needs the user's coarse location, which the app already has for the map, and
  the WeatherKit capability on the Apple Developer account. Without it the app runs on rotation.
- One more reason to keep the palette in a package: five skins × two appearances × every pairing is
  a test that runs in a second on a Mac, and could not run at all in the app.
