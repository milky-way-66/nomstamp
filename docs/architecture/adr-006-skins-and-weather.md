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

**Two accents are told apart by hue, not by lightness.** Both have to clear AAA against the same
paper, which forces their luminances close together, so a contrast test between them would only be
re-asserting that. TC-N-18 measures hue separation instead and requires 40°. This is a legibility
floor, not the distinction itself: pins are still told apart by shape and glyph first (NFR-6.3).

**The skin name crosses the package boundary as a string.** `Skin` exists twice — in the domain,
which decides which printing the day calls for, and in `FoodMapDesign`, which owns what a printing
looks like. Neither package depends on the other and neither should, so the composition root maps
one to the other in a single exhaustive switch; a case added on one side and not the other fails to
compile there.

**The skin is a stored value on `Theme`, and the root rebuilds when it changes.** Every view that
draws chrome reads these tokens, and threading a skin through all of them would be a large change
for something that is, by construction, identical everywhere on screen. `AppearanceStore` writes it
and the root view carries `.id(skin)`, so a new printing rebuilds the tree — affordable because
re-inking happens roughly once a day, and on a change of sky or scene phase.

**Contrast is checked per skin.** `Palette.renderedPairings(for:)` is a function of the skin, and
TC-N-18 walks every skin in both appearances. A skin that cannot meet the levels is not a skin.

**Weather comes from WeatherKit, behind a port.** `WeatherPort` lives in the domain; the adapter in
`FoodMapData` wraps WeatherKit and returns nil for anything it cannot answer — no permission, no
entitlement, no network, a throw. Nil is not an error state in the interface: it is the rotation.

**Two launch arguments make it photographable.** `-ForceSkin <name>` pins the printing and
`-ForceNight` pins the night market. The second exists because the appearance now follows the sun
rather than the system setting, so flipping the simulator to dark no longer reaches the app, and
the night market would otherwise only be capturable after sunset.

## Consequences

- Colour tokens are named for their role (`visitedInk`, `wishlistInk`), not for a hue. A token
  called `pandan` painting tamarind orange would be a lie.
- The weather reading needs the user's coarse location, which the app already has for the map, and
  the WeatherKit capability on the Apple Developer account. Without it the app runs on rotation.
- One more reason to keep the palette in a package: five skins × two appearances × every pairing is
  a test that runs in a second on a Mac, and could not run at all in the app.
