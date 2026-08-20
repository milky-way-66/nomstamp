# ADR-008 — Friends: stamps that other people can see

**Status:** proposed
**Supersedes** the "private by default, no sharing in v1" assumption in `use-cases.md`, and
**amends CON-1, CON-3 and NFR-1** in the SRS — see *What this costs the promise* below.
**Context:** the app has always been one person's stamp book. The ask is to let a reader connect
with friends and see friends' stamps on the same map. Three of the product's own constraints stood
in the way — no backend, no accounts, and photographs never leaving the device. The first two are
protecting something real and survive in amended form. The third has been dropped deliberately: a
stamp with no photograph is not a stamp.

## Decision

Friends' stamps sync **live, through the reader's own iCloud, over CloudKit**. There is no server
to operate, no bucket to pay for and no account to create.

### Why not Firebase or Supabase

Both were considered and both fail the *free* constraint on facts, not on taste:

| | Why it fails |
|---|---|
| Firebase Storage | Since **3 February 2026** a Spark project has no Cloud Storage buckets at all — calls return 402/403. Storing one byte requires Blaze, a real billing account, with no spend ceiling |
| Supabase | 1 GB file storage and 5 GB egress **per project, not per user** — every reader's photos sit in one bucket we own. Worse: a free project with no requests for **7 consecutive days pauses** until someone logs into a dashboard |

Both also make us the custodian of other people's photographs and movement history: auth to build,
security rules that must be perfect, a breach to own. CloudKit puts that inside Apple's boundary,
where the reader's own iCloud quota pays for the reader's own data.

The app is iPhone-only by CON-4, so the usual objection to CloudKit — that it strands other
platforms — costs us nothing we had.

## Identity is the Apple ID, and that is the smallest one available

A device-local keypair was considered first and is genuinely appealing: no account of any kind. It
does not survive contact with *live* sync. A key in the Keychain cannot deliver a stamp to a friend
without something in the middle, and the moment there is something in the middle, that thing knows
who you are. Apple ID is the smallest such thing on offer — the reader already has one, we never
see it, and we store no credential.

- We create no accounts, run no login screen and hold no password.
- A friend is a **CloudKit share participant**, nothing more.
- A reader with no iCloud account keeps the whole app; they lose only the friends layer, which
  must degrade to an explanation rather than a broken screen (NFR-4.3).

## Topology: publish a projection, subscribe to friends'

The reader's own data **does not move**. The existing SwiftData store stays exactly as it is, local
and authoritative, and is not migrated onto CloudKit sync.

Instead, each reader gets one CloudKit record zone holding a **projection** of the places they chose
to share, and a `CKShare` over that zone whose participants are their friends. Friends' zones arrive
in the reader's *shared* database.

```
SwiftData (local, authoritative)  ──projection──▶  my zone ──CKShare──▶ friends
friends' zones ──subscription──▶  friend cache (local, disposable)
```

Two properties follow, and both are the reason for this shape:

1. **Friend stamps are a cache, never a source of truth.** They can be deleted and refetched. No
   migration, no conflict resolution on data we did not author, and a corrupt cache is a nuisance
   rather than data loss (NFR-3.1).
2. **We do not depend on SwiftData's CloudKit sharing.** Sharing support there is thin; raw
   `CKRecord`/`CKShare` with **`CKSyncEngine`** for the projection is the path with fewer unknowns.
   `CKSyncEngine` owns the state serialisation, batching and retries that would otherwise be ours.

Invitation is a share URL sent through the ordinary share sheet — Messages, AirDrop, anything. The
friend taps it, the app handles `userDidAcceptCloudKitShareWith`, and the connection is live from
then on. The gesture is still *handing someone your book*; it just stays open afterwards.

## A stamp is a place, not a meal

This is the single most consequential line in the document. A friend's stamp carries **one record
per place**, not per visit.

| Carried | Withheld |
|---|---|
| Place name, coordinate, `providerPlaceID` | The visit-by-visit timeline |
| Average rating, to the half star | Individual meal ratings |
| Number of visits | Exact timestamps — see below |
| Most recent dish name | Price, always |
| Month last visited — `2026-08`, never a day | Notes, unless opted in per place |
| One 240 px thumbnail: the pin photo | Full-size photographs (v1) |

A per-meal feed would export a movement history: where this person is, on which evenings, over
years. A per-place stamp says *Lan has eaten here three times and rates it 4.5*, which is the entire
emotional payload of the feature at a fraction of the exposure. Month precision on the date is the
same trade — enough to know a stamp is fresh, not enough to reconstruct a week.

Price never travels. Notes travel only where the reader opts in per place, because a note is the
most personal field in the model — *"Lan said the pho is great"* is about a third party who did not
agree to anything.

## How the photograph travels

One thumbnail per place, as a `CKAsset`, and it is **the thumbnail the pin already renders**
(`Place.pinPhoto`, NFR-2.4, NFR-8.2).

- 240 px square at JPEG q0.7 is roughly **15 KB**. The 2048 px original is ~500 KB. Syncing
  originals would cost thirty times more for pixels almost nobody opens.
- The asset is fetched **lazily**, when a friend's pin comes into view, then cached to disk and
  never fetched again. The record arrives in under a second; the image arrives when it is needed.
- Full-size photographs do not leave the device in v1. Fetching an original on demand when a friend
  opens the place is a deliberate v2, not an oversight.

**Every thumbnail that leaves is stripped of EXIF first.** The photo pipeline records `exif_lat`
and `exif_lng`; shipping those inside a shared image would leak precise coordinates of everything a
reader photographs, silently, past every other protection in this document. Stripping is a domain
rule with its own test, not a line in a sync adapter.

## Sharing is per place, opt-in, and revocable

Nothing is shared by default. A place carries one *shared* toggle; settings offers a bulk
"share all my visited places" that shows the count before it acts.

Turning a place off **deletes its record from the zone**. This is the one place where live sync is
strictly better than a file you send: with a snapshot, anything you ever sent is gone forever.
Here, unsharing genuinely retracts, and removing a friend genuinely removes their access.

## Matching places across people — the countersign

Two readers who ate at the same shop hold two different local `UUID`s for it. The friends layer is
worthless unless those resolve to one pin, so matching runs in this order:

1. `providerPlaceID` equal — exact, and free when both saved the place from search.
2. Otherwise `PlaceMatcher` (already in `Domain/Services`): name similarity within a distance bound.
   A-2 says much Vietnamese street food is in no database and gets dropped as a manual pin, so this
   path is the common one here, not the fallback.
3. Otherwise the friend's stamp stands as its own pin in the friend layer.

When a match lands on a place the reader has also stamped, the pin shows a **countersignature** — a
second, smaller stamp overlapping the reader's own at an angle, in the friend's ink. `StampTilt` and
`StampCut` already exist; this is a new arrangement of solved primitives, not new machinery. It is
also the moment the feature is *about*: not "here is a list of what my friends ate" but "we have
both been here".

## Art direction: a friend's ink

Each friend is assigned an ink **derived deterministically from their participant identifier**, so
Lan is the same colour on every device that knows her, with nothing coordinated and nothing stored.
The derivation selects from a **curated set of six inks in the palette** — never free-form colour —
so it cannot produce something off-brand or below the contrast floor TC-N-07 enforces.

Colour is never the only signal (NFR-6.3): the reader's own stamps keep a solid edge, friends' carry
a perforated one. VoiceOver names the friend (NFR-6.2).

The friends layer is a **layer toggle on the map, not a fourth tab**. The tab bar answers *what kind
of place*; whose stamps are showing is a different question and a fourth tab would conflate them.

## Layering

CloudKit is an Apple framework and therefore never appears in the domain (CON-5, NFR-7.1).

| Where | What |
|---|---|
| `FoodMapDomain/Entities` | `Friend`, `FriendStamp`, `SharedStamp` |
| `FoodMapDomain/UseCases` | `BuildSharedStampUseCase` — the projection *and the redaction rules* |
| | `MergeFriendStampsUseCase` — matching, countersign resolution |
| `FoodMapDomain/Ports` | `StampSharingPort`, `FriendDirectoryPort` |
| `FoodMapData/Sharing` | `CKSyncEngine`, `CKShare`, assets, EXIF stripping |

The rule about **what is allowed to leave the device** lives in the domain, where it is unit-tested
on macOS in under five seconds with no simulator and no network (NFR-7.2, NFR-7.5). That placement
is the point: a redaction rule buried in a sync adapter is a rule nobody can prove.

## What this changes on screen

1. **The map gains a layer.** Friends' stamps appear in their own ink under a layer control; the
   reader's own map is unchanged when the layer is off, which is the default on first launch.
2. **Pins can be countersigned.** A place both parties have stamped shows two overlapping stamps.
3. **Place detail gains an *also stamped by* row** — who, their score, which month.
4. **A Friends screen**: who is connected, how many stamps each shares, and a remove that revokes.
5. **A share toggle on each place**, plus the bulk action in settings that states the count first.
6. **An invitation flow** — generate a share link, send it through the ordinary share sheet.

## What this costs the promise

CON-3 — *photographs never leave the device* — is **removed**, deliberately and with the trade
understood. It is replaced rather than simply deleted, because "photos leave now" is not a policy:

- Nothing leaves except by an **explicit per-place act**, never automatically.
- What leaves is bounded by the stamp table above and by nothing else.
- Thumbnails only, EXIF stripped, no originals.
- Unsharing retracts; removing a friend revokes.
- The reader's photographs are stored against **their own iCloud quota**, not on infrastructure we
  own, and we never hold a copy.

NFR-1.3 — *the only outbound traffic is Apple Maps* — widens to Apple's iCloud hosts. Its
verification, a network inspection showing no non-Apple host, still holds and is still worth
running. NFR-1.4 survives unchanged: we collect no account and no identifying data, because Apple
holds the identity and we never see it.

## Consequences

- **Sync bugs are a new class of defect** the four suites have no shape for: acceptance flows,
  offline queues, partial zone fetches, a friend who revokes mid-fetch. These need their own test
  cases before any of it is built.
- **`CKShare` has quota edge cases.** Creation can fail with `quotaExceeded` for a non-primary
  member of a Family iCloud plan. That is a real reader hitting a real wall and needs a message
  that explains it (NFR-4.4), not a silent failure.
- **The friends layer must be entirely optional.** No iCloud, no network, or no interest — the app
  is exactly what it was.
- **Everything friend-shaped is disposable.** If the cache is wrong, delete it and refetch. No
  friend data is ever the only copy of anything.
- **This does not weaken the local-first core.** Logging a meal still works with no network
  (NFR-3.2) and touches none of this.
- Adding a field to the stamp table is a change to this document first. What leaves the device is
  not a decision to make at a call site.
