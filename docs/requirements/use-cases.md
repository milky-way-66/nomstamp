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
1. User taps **Add meal**.
2. App opens the camera; user takes one or more photos of the dish.
3. App reads the current GPS position and asks the Place Provider for nearby candidates.
4. App shows the nearest candidates; user taps the correct restaurant.
5. User optionally adds: dish name, rating, note, price.
6. User taps **Save**.
7. App uploads the photos, creates a `Meal` linked to that `Place`, and confirms.

**Alternate flows**
- **1a. Photo already taken** — user picks an existing photo from the gallery. If the photo carries EXIF GPS + timestamp, the app uses those instead of the current position (this is what makes logging *after* the meal work).
- **4a. Place not in the list** — user searches by name, or drops a pin manually and types the name.
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
- The happy path from tapping “Add meal” to a saved meal takes **no more than 3 taps** beyond the photo itself.

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

---

## UC-3 — Open a place and see its meals
**Serves:** US-2 · **Priority:** must-have

- **Trigger:** User taps a pin (or a row in the list view).

**Main flow**
1. App opens the place detail: name, address, distance, and the pin kind.
2. Photos of every meal eaten there are shown newest-first, each with date, dish name, rating and note.
3. User can tap a photo for a full-screen view, edit or delete a meal, or get directions.

**Alternate flow**
- **2a. Wishlist place** — there are no meals yet; instead the app shows the saved source/note ("Lan said the pho here is great") and a prominent **“I ate here”** action (UC-6).

**Acceptance criteria**
- Given a place with 3 meals, when I open it, then I see all 3 photos ordered newest first.
- Given a wishlist place, when I open it, then I see why I saved it and can log a meal in one tap.

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

**Acceptance criteria**
- Given a wishlist place, when I log a meal there, then its pin becomes a visited pin showing my photo, and the note I saved is not lost.

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
