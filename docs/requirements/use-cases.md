# Use Cases

Derived from `user-stories.md`. Each use case names the story it serves.

Actor throughout: **User** (a single signed-in person managing their own food map).
Supporting actors: **Device** (camera, GPS), **Place Provider** (map/geocoding service).

---

## UC-1 — Log a meal with a photo
**Serves:** US-1 · **Priority:** must-have (core loop)

- **Precondition:** User is signed in. App has camera permission (or the user picks from the gallery).
- **Trigger:** User is at a restaurant with food in front of them and taps “Add meal”.

**Main flow**
1. User taps **Add meal** (`+`). The camera opens straight away — no form stands between the tap and the shutter.
2. User takes a photo of the dish.
3. App asks one question: how was it? User taps a star (or skips).
4. Meanwhile the app reads the coordinate — the photo's own EXIF if it has one, otherwise the
   current GPS fix — and preselects the place: a place already saved within 120 m, else the
   nearest candidate from the Place Provider.
5. App shows the confirm step with the photo, place, score and time already filled in. The user
   changes anything that is wrong; dish name, note and time sit behind one disclosure.
6. User taps **Save**.
7. App stores the photos, creates a `Meal` linked to that `Place`, and confirms.

**Alternate flows**
- **1a. Photo already taken** — user picks an existing photo from the gallery. If the photo carries EXIF GPS + timestamp, the app uses those instead of the current position (this is what makes logging *after* the meal work).
- **4a. Nothing to preselect, or the guess is wrong** — user opens the place picker from the confirm step and searches by name, or drops a pin manually and types the name.
- **4b. Place is already on the map as a Wishlist pin** — it appears at the top of the candidate list; selecting it converts it to Visited (see UC-6).
- **6a. Offline** — the meal is saved locally and queued; upload retries when connectivity returns. The pin appears on the map immediately, marked as pending sync.

**Exception flows**
- **E1. Location permission denied** — app skips step 3 and goes straight to search (4a). Logging must never be blocked by a denied location permission.
- **E2. Upload fails** — the meal is kept locally with a retry action; it is never silently dropped.

**Postcondition:** A `Meal` exists with ≥1 photo, a timestamp, and a `Place`. The place shows as a Visited pin.

**Acceptance criteria**
- Given I am at a restaurant, when I take a photo and save, then a meal is stored with that photo, the current time, and a place.
- Given location is unavailable, when I log a meal, then I can still choose a place by searching.
- Given I go offline mid-save, when I reopen the app online, then the meal uploads without me doing anything.
- Given I tap **Add meal**, then the very next thing I see is a live camera.
- Given a photo and a place nearby, when I reach the confirm step, then the place and the time are already filled in and I may still change them.
- The happy path from tapping “Add meal” to a saved meal takes **no more than 3 taps** beyond the photo itself: one star, one Save — and nothing else is required.

---

## UC-2 — Browse my food map
**Serves:** US-2 · **Priority:** must-have

- **Precondition:** User is signed in.
- **Trigger:** User opens the app / the Map tab.

**Main flow**
1. App shows a map centred on the user's current location (or the last viewed area).
2. App loads the user's places within the visible bounds.
3. Each place renders as a pin: Visited pins show a **thumbnail of the food photo**; Wishlist pins show a distinct “want to try” marker.
4. Dense areas collapse into clusters showing a count; zooming in expands them.
5. User pans/zooms; pins reload for the new bounds.
6. User taps a pin and that place opens (UC-3) — the same destination as tapping its row in the
   list. A cluster lists what is inside it first, and choosing one of those opens it too.

**Alternate flows**
- **1a. First run, no places yet** — an empty state explains the app and offers “Add your first meal”.
- **3a. Several meals at one place** — one pin per place, badged with the meal count; the thumbnail is the most recent meal.
- **5a. Filters** — user filters by kind (visited / wishlist), rating, or date range.

**Postcondition:** User can see, at a glance, what they ate and where.

**Acceptance criteria**
- Given I have logged meals, when I open the map, then I see a pin at each place with a photo thumbnail.
- Given two meals at the same restaurant, then I see one pin, not two.
- Given 200 pins in view, then the map stays responsive by clustering.
- Visited and wishlist pins are distinguishable without tapping them.
- Given a pin, when I tap it, then that place opens — a pin is not merely decoration.

---

## UC-3 — Open a place and see its meals
**Serves:** US-2 · **Priority:** must-have

- **Trigger:** User taps a pin (or a row in the list view).

**Main flow**
1. App centres the map on the place's pin and opens the place detail over the map — not covering
   it — showing name, address, distance and the pin kind.
2. Photos of every meal eaten there are shown newest-first, each with date, dish name, rating and note.
3. User can tap a photo for a full-screen view, edit or delete a meal, or get directions.
4. Going back leaves the map where the place put it, so the pin stays in view.

**Alternate flow**
- **2a. Wishlist place** — there are no meals yet; instead the app shows the saved source/note ("Lan said the pho here is great") and a prominent **“I ate here”** action (UC-6).

**Acceptance criteria**
- Given a place with 3 meals, when I open it, then I see all 3 photos ordered newest first.
- Given a wishlist place, when I open it, then I see why I saved it and can log a meal in one tap.
- Given any place, when I open it, then the map has moved to its pin and I can still see the map.
- Given an open place, when I go back, then the map is still centred on that place.

---

## UC-4 — Save a place I heard about
**Serves:** US-3 · **Priority:** must-have

- **Precondition:** User is signed in.
- **Trigger:** Someone recommends a place, or the user reads about one.

**Main flow**
1. User taps **Save a place**.
2. User searches for it by name (optionally scoped to a city).
3. App shows matches from the Place Provider; user picks one.
4. User optionally adds a note (who recommended it, what to order) and tags (e.g. `ramen`, `Tokyo`).
5. User saves; the place appears on the map as a **Wishlist** pin.

**Alternate flows**
- **2a. Not findable by search** — user long-presses the map to drop a pin at the right spot and names it manually.
- **3a. Place is already saved** — app says so and opens the existing place instead of creating a duplicate.

**Postcondition:** A `Place` of kind *wishlist* exists with an optional note, visible on the map.

**Acceptance criteria**
- Given I search a restaurant name, when I pick a result and save, then a wishlist pin appears at its location.
- Given a place I already saved, when I try to save it again, then no duplicate is created.
- Given I saved a place with a note, then that note is visible when I open the pin later.

---

## UC-5 — Find saved places near me while travelling
**Serves:** US-3 (the payoff half) · **Priority:** must-have — *US-3 is worthless without it*

- **Precondition:** The user has wishlist places saved.
- **Trigger:** User arrives in a city and wants to know if they saved anything nearby.

**Main flow**
1. User opens the map in the new location (or searches for the city).
2. App shows the user's places within the visible area — wishlist pins prominent.
3. User taps **Near me**; app lists saved places within a radius, sorted by distance.
4. User picks one and gets directions (UC-3).

**Alternate flow**
- **2a. Nothing saved here** — app says so plainly rather than showing an ambiguous empty map.

**Acceptance criteria**
- Given I saved a place in Tokyo and I am now in Tokyo, when I open “Near me”, then that place is listed with its distance.
- Given I am somewhere with nothing saved, then the app tells me clearly that there is nothing nearby.

---

## UC-6 — Mark a wishlist place as visited
**Serves:** the bridge between US-3 and US-1 · **Priority:** should-have

- **Trigger:** User finally eats at a place they had saved.

**Main flow**
1. From the place detail, user taps **“I ate here”**.
2. App runs UC-1 from the photo step, pre-filling the place.
3. On save, the place's kind changes from *wishlist* to *visited*; the pin's appearance changes and the original recommendation note is kept.

**Alternate flow**
- **3a. The last meal is deleted** — the place reverts to a wishlist place rather than
  disappearing, and the note explaining why it was saved is kept. Because `kind` is derived
  from whether any meals exist, this needs no separate handling; the test exists so a later
  refactor to a stored flag cannot silently break it.

**Acceptance criteria**
- Given a wishlist place, when I log a meal there, then its pin becomes a visited pin showing my photo, and the note I saved is not lost.
- Given a visited place with one meal, when I delete that meal, then the place remains as a wishlist place with its note intact.

---

## UC-7 — Rate a meal
**Serves:** US-1 (remembering *how good* it was, not just that it happened) · **Priority:** must-have

- **Trigger:** User is logging a meal, or is looking back at one they logged before.

**Main flow**
1. While logging a meal, user taps a star to score it out of five.
2. App stores the rating with the meal.
3. The place's detail shows each meal's stars, and the place itself shows the average of them.

**Alternate flows**
- **1a. Rated later or changed** — user taps the stars on a meal they already logged; the new
  score replaces the old one immediately, with no separate edit screen.
- **1b. Rating cleared** — user taps the star already selected; the rating returns to none,
  because a wrong score is worse than no score.

**Exception**
- **E1. Out-of-range score** — a score below 1 or above 5 is rejected rather than stored.

**Acceptance criteria**
- Given a meal with no rating, when I tap the fourth star, then the meal shows four stars.
- Given a meal rated 4, when I tap the fourth star again, then it shows no rating.
- Given a place with meals rated 5 and 4, then the place shows an average of 4.5.

---

## Domain model (implied by the above)

```
User 1───* Place 1───* Meal 1───* Photo
```

- **Place** — `id`, `user_id`, `name`, `address`, `lat`, `lng`, `kind` (`visited` | `wishlist`),
  `note`, `tags[]`, `provider_place_id` (for dedupe), `created_at`.
  `kind` is derived: a place with ≥1 meal is *visited*, otherwise *wishlist*.
- **Meal** — `id`, `place_id`, `eaten_at`, `dish_name?`, `rating?`, `note?`, `price?`, `created_at`.
- **Photo** — `id`, `meal_id`, `storage_path`, `width`, `height`, `taken_at?`, `exif_lat?`, `exif_lng?`.

Splitting **Meal** from **Place** is what makes UC-2's "one pin per restaurant, many photos"
work; if photos hung directly off places, repeat visits could not be told apart.

---

## Open questions (my assumptions in **bold** — correct me and I will adjust)

1. **Private by default.** No sharing, following, or public feed in v1. Sharing is a large second system; I've left it out until you ask.
2. **Mobile-first.** The core loop (UC-1) happens standing in a restaurant holding a phone. I'll build a responsive web app that works well on a phone; a native app is a later step if you want camera/offline to feel truly native.
3. **One user, one map.** No shared/group maps in v1.
4. **Ratings are 1–5 stars**, optional.
5. **Wishlist entries are places, not dishes.** "Try the ramen at X" is a note on the place, not its own entity.
