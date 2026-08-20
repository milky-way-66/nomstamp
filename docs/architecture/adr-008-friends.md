# ADR-008 — Friends: stamps that other people can see

**Status:** **superseded by `adr-009-friends-shared-zone.md`.** The transport decided here — a
peer-to-peer mesh over iroh — was replaced once the both-awake constraint below was followed
through to the feature's actual behaviour. This document is kept because the reasoning that led
here is still the reasoning that justifies the product rules ADR-009 carries over unchanged: the
in-person connection, the cap of eight, and the stamp being a place rather than a meal. Where the
two disagree, ADR-009 wins.
**Research:** `research-friend-sync.md` — five transport families surveyed before this was chosen.
**Amends CON-3 and NFR-1** in the SRS. **CON-1 and CON-2 survive intact**, which is the point.
**Context:** the app has always been one person's stamp book. The ask is to let a reader connect
with friends and see friends' stamps on the same map — live, not as a file posted back and forth,
and with no backend and no money.

## Decision

Friends' devices talk **directly to each other over iroh**. There is no server, no bucket, no
account and no bill.

A reader's identity is an **ed25519 keypair generated on first launch**. iroh dials a peer *by its
public key rather than its IP address*, so that keypair is the whole of the account: nothing to
register, nothing to log into, nothing for us to hold or lose.

| | |
|---|---|
| Transport | QUIC, direct where possible (~90% via hole-punching), relayed otherwise |
| Connecting | In person only — QR plus a local radio handshake. Capped at eight friends |
| Identity | ed25519 public key — the iroh `NodeId` |
| Images | `iroh-blobs`: content-addressed BLAKE3, resumable, deduplicating |
| iOS support | Official Swift bindings via uniffi |
| Cost | Nothing. No storage we own, no egress we pay, no plan to upgrade |

### Why not the alternatives

CloudKit and a Cloudflare Workers stack both work and both were rejected for the same reason: they
buy **store-and-forward** — a thing that is awake when neither person is — and the decision taken is
that a food journal does not need it (see *The cost of no backend*, below). Firebase now requires a
billing account with no spend ceiling; Supabase pauses free projects after seven quiet days. A file
sent through the share sheet needs no infrastructure at all but ships snapshots, cannot retract, and
cannot update.

## Is this honestly "no backend"?

Nearly, and the gap should be stated rather than glossed.

We write, deploy and operate **nothing**. But ~5–10% of connections fail to hole-punch and fall back
to **relays** — free, rate-limited, stateless servers run by n0, which see only encrypted bytes and
store nothing. That is third-party infrastructure, and a dependency that could in principle be
withdrawn or throttled.

Three things make it acceptable: relays cannot read what passes through them, they are needed only
for the minority of connections, and a relay can be self-hosted later without touching the app's
data model.

**This needs a spike against Vietnam specifically.** The primary market is on mobile networks that
lean heavily on CGNAT, and CGNAT is exactly what defeats hole-punching. The 90% direct-connection
figure is a global average; the Hanoi-to-Saigon figure over two mobile carriers is the number that
actually matters, and we do not have it.

## Connecting: in the room, or not at all

Adding a friend exchanges public keys and nothing else, and it can **only happen in person**.

One reader shows a QR code carrying their iroh ticket; the other scans it. The handshake then
completes **over local radio** — Wi-Fi Aware where available, falling back to the local network — and
the inviter confirms. **The first sync runs immediately, in the room**: the friend's stamps land on
the map while both are still at the table.

**A QR code alone would not enforce proximity** — it can be screenshotted and forwarded across the
country. The radio leg is what makes co-presence real, because radio range cannot be faked remotely.
The QR carries the ticket; the radio proves the room. (UWB via `NearbyInteraction` could require the
phones be touched together; it needs an iPhone 11 or newer and is a flourish, not a foundation.)

### Why no remote invitation

A link sent through Messages was specified and then **removed deliberately**. The cost is real and
worth naming: a distant friend's stamps are arguably the most valuable on the map, being places the
reader would otherwise never see, and a reader whose friends have all moved away can now connect to
nobody.

It is paid anyway, for three returns:

1. **A connection means something.** You have eaten near this person. That is a different social
   object from a follow, and it is the one the product wants.
2. **Spam and unwanted contact become structurally impossible**, rather than defended against. No
   forwarded link, no stranger request, no block list, no moderation surface at all.
3. **It is the only path where the feature demonstrates itself.** Sync needs both phones awake, and
   two people at one table definitionally are. Remotely, a reader adds a friend and may then watch an
   empty layer for three days while everything works correctly — a far worse first impression than a
   failure would be.

Should this prove too strict in use, a remote invitation is additive and can be introduced without
touching the data model. Going the other way — withdrawing it later — would break connections people
already made. Strict first is the reversible order.

### Either way

Adding is **mutual** — until both sides hold each other's key, nothing flows, and one-way following
does not exist. The display name is **self-asserted and unverified**: a label the reader chose, not a
claim anyone checked. The public key is the only real identity, so where it matters the interface
shows a short fingerprint of it rather than trusting the name.

## Eight friends, and no more

The friend list is capped at **eight**.

This is a product decision before it is a technical one. A cap forces curation, which is the same
argument as requiring proximity: a small, deliberate circle is a different thing from a following.
With eight slots, adding someone is a choice and removing someone is meaningful.

It also falls out of the art direction. Every friend needs an **ink** that clears the AAA contrast
floor TC-N-07 enforces, in light and dark, over paper texture, while still reading as part of one
palette. That supply is genuinely limited; eight is about where a curated set holds before it starts
to look like a box of crayons. Beyond it, two friends share a colour and the map stops answering
*whose stamp is that* at a glance.

Reaching the cap is not an error state. The interface says the circle is full and offers to remove
someone — there is no upgrade, no tier, and nothing to buy.

**Eight is a judgement, not a measurement.** It is deliberately low because a cap is easy to raise
later and painful to lower: lowering orphans connections people already made, while raising is
invisible to everyone who never hit it.

## Sync happens when it can

There is no delivery guarantee, by design. On foreground, on network change, and on the best-effort
`BGAppRefreshTask` iOS grants, the app dials each known friend and reconciles:

1. Exchange a **manifest** — for each shared place, an id, a version and the thumbnail's BLAKE3 hash.
2. Diff it. Request only what changed.
3. Pull missing thumbnails by hash through `iroh-blobs`; content addressing means an image already
   held is never fetched twice, by anyone, ever.

Because friend data is **read-only and single-author**, no CRDT is needed. Nobody ever edits a
friend's stamp, so per-place records versioned by their author with last-write-wins is correct — and
a fraction of the work of a merge engine.

## The cost of no backend

**Two phones must be awake at the same time.** This is the price of the decision and it must be
carried honestly in the interface, not hidden:

- A friend's stamps are shown **with the date they were last received** — *"Lan, as of 12 August"* —
  never presented as current when they are not.
- Sync is never described as instant, and a stamp appearing late is not a bug report.
- Two friends who open the app at different times of day may go a long while without overlapping.
  We do not yet know how often this bites; it is the second thing to spike.

**If overlap proves too rare**, the escape hatch is already implied by the design and requires no
server: stamps are **signed by their author**, so any friend's device can carry a bundle onward
intact and the recipient can still verify it came from its author. A friend-of-friend mesh, where
Minh's phone ferries Lan's stamps to me because Minh overlapped with each of us separately, is
store-and-forward built out of the friends themselves. It also needs per-recipient encryption so a
carrier cannot read what it carries, which is why it is **not in v1** — but the signature scheme in
v1 is chosen so this stays open.

**Retraction is best-effort.** Unsharing a place writes a tombstone that propagates on the next
connection. Better than a file, which can never be recalled; weaker than a server, which can revoke
centrally. Say so plainly rather than promising deletion.

## A stamp is a place, not a meal

The single most consequential line in this document. A friend's stamp carries **one record per
place**, never per visit.

| Carried | Withheld |
|---|---|
| Place name, coordinate, `providerPlaceID` | The visit-by-visit timeline |
| Average rating, to the half star | Individual meal ratings |
| Number of visits | Exact timestamps — see below |
| Most recent dish name | Price, always |
| Month last visited — `2026-08`, never a day | Notes, unless opted in per place |
| One 240 px thumbnail: the pin photo | Full-size photographs (v1) |

A per-meal feed exports a movement history: where this person is, on which evenings, for years. A
per-place stamp says *Lan has eaten here three times and rates it 4.5*, which is the entire emotional
payload at a fraction of the exposure. Month precision is the same trade — enough to know a stamp is
fresh, not enough to reconstruct a week.

Price never travels. Notes travel only where the reader opts in per place, because a note is the most
personal field in the model — *"Lan said the pho is great"* is about a third party who agreed to
nothing.

## How the photograph travels

One thumbnail per place, and it is **the thumbnail the pin already renders** (`Place.pinPhoto`,
NFR-2.4, NFR-8.2).

- 240 px square as **HEIC** is roughly **7–10 KB**; the 2048 px original is ~500 KB. A whole
  500-place map is therefore about **5 MB** — one QUIC stream, and nothing anyone need pay for.
- Blobs are fetched **lazily**, as a friend's pin comes into view, then cached on disk forever.
- Full-size photographs do not leave the device in v1. Fetching an original on demand when a friend
  opens the place is a deliberate v2, and cheap over an already-open connection.

**Every thumbnail is stripped of EXIF before it leaves.** The photo pipeline records `exif_lat` and
`exif_lng`; shipping those inside a shared image would silently leak precise coordinates of
everything a reader photographs, past every other protection here. Stripping is a **domain rule with
its own test**, never a line in a transport adapter.

## Sharing is per place, opt-in

Nothing is shared by default. A place carries one *shared* toggle; settings offers a bulk
"share all my visited places" that states the count before it acts.

## Matching places across people — the countersign

Two readers who ate at the same shop hold two different local `UUID`s for it. The layer is worthless
unless those resolve to one pin, so matching runs in order:

1. `providerPlaceID` equal — exact, and free when both saved the place from search.
2. Otherwise `PlaceMatcher` (already in `Domain/Services`): name similarity within a distance bound.
   A-2 says much Vietnamese street food is in no database and arrives as a manual pin, so this is the
   common path here, not the fallback.
3. Otherwise the friend's stamp stands as its own pin.

Where a match lands on a place the reader has also stamped, the pin shows a **countersignature** — a
second, smaller stamp overlapping the reader's own at an angle, in the friend's ink. `StampTilt` and
`StampCut` already exist; this is a new arrangement of solved primitives. It is also the moment the
feature is *for*: not "a list of what my friends ate" but **"we have both been here"**.

## Art direction: a friend's ink

Each friend's ink is derived deterministically **from their public key**, so Lan is the same colour
on every device that knows her, with nothing coordinated and nothing stored. The derivation selects
from a **curated set of eight inks in the palette** — never free-form colour — so it cannot produce
something off-brand or below the contrast floor TC-N-07 enforces. Where a derived ink is already
taken, the next free one is used: **local uniqueness beats cross-device stability**, because a map
where two friends share a colour fails at the only job the ink has. With the list capped at eight and
the palette holding eight, a free ink always exists.

Colour is never the only signal (NFR-6.3): the reader's own stamps keep a solid edge, friends' carry
a perforated one. VoiceOver names the friend (NFR-6.2).

The friends layer is a **layer toggle on the map, not a fourth tab**. The tab bar answers *what kind
of place*; whose stamps are showing is a different question, and a fourth tab would conflate them.

## Layering

iroh is a networking framework and therefore never appears in the domain (CON-5, NFR-7.1).

| Where | What |
|---|---|
| `FoodMapDomain/Entities` | `Friend`, `FriendStamp`, `SharedStamp`, `StampManifest` |
| `FoodMapDomain/UseCases` | `BuildSharedStampUseCase` — the projection *and the redaction rules* |
| | `ReconcileManifestUseCase` — the diff, with no network in sight |
| | `MergeFriendStampsUseCase` — matching, countersign resolution |
| `FoodMapDomain/Ports` | `PeerIdentityPort`, `StampSyncPort`, `BlobStorePort` |
| `FoodMapData/Sharing` | iroh endpoint, tickets, `iroh-blobs`, EXIF stripping, Keychain |

Two consequences worth having on purpose:

- The rule about **what may leave the device** lives in the domain, unit-tested on macOS in under
  five seconds with no simulator and no network (NFR-7.2, NFR-7.5). A redaction rule buried in a
  transport adapter is a rule nobody can prove.
- The **manifest diff is pure logic**, so the hardest part of sync is testable without two phones.

Keeping the transport behind `StampSyncPort` also means that if the both-awake constraint proves
intolerable, moving to CloudKit or a relay of our own is a data-layer change, not a rewrite.

## What this changes on screen

1. **The map gains a layer.** Friends' stamps in their own ink under a layer control; the reader's
   own map is untouched when the layer is off, which is the default.
2. **Pins can be countersigned** — a place both parties have stamped shows two overlapping stamps.
3. **Place detail gains an *also stamped by* row** — who, their score, which month.
4. **A Friends screen**: who is connected, their key fingerprint, how many stamps they share, **when
   each was last reached**, and a remove.
5. **A share toggle on each place**, plus the bulk action that states its count first.
6. **An invitation flow** — a QR code to hold up across a table, and a scanner for the other side.
   Incoming requests are confirmed by the inviter, never silent. A full circle says so and offers to
   remove someone rather than failing.

## What this costs the promise

CON-3 — *photographs never leave the device* — is **removed**, deliberately: a stamp with no
photograph is not a stamp. It is replaced rather than deleted, because "photos leave now" is not a
policy:

- Nothing leaves except by an **explicit per-place act**, never automatically.
- What leaves is bounded by the stamp table above and by nothing else.
- Thumbnails only, EXIF stripped, no originals.
- Bytes travel **encrypted, device to device**. No third party holds a copy — not us, not Apple, not
  a bucket. Relays, where used, carry ciphertext and retain nothing.

CON-1 (*no backend, no server, no accounts*) and CON-2 (*no paid APIs, no shipped keys*) **survive
unchanged**, which is why this option was chosen over the ones that would have amended them.

NFR-1.3 — *the only outbound traffic is Apple Maps* — widens to include peer connections and relay
fallback. NFR-1.4 survives: no account, no login, no identifying data collected, because the identity
is a key the device generated and nobody registered.

## Consequences

- **Sync is a new class of defect** the four suites have no shape for: half-open connections, a
  friend who revokes mid-fetch, partial manifests, a peer that vanishes. These need test cases before
  any of it is built.
- **A Rust FFI dependency is new to this project.** Binary size, build reproducibility and the effect
  on CI all need measuring, not assuming.
- **Battery.** Holding a QUIC endpoint and a relay connection costs power. Sync must be bounded,
  opportunistic and cancellable, never a background daemon.
- **A new device is a new identity.** The key lives in the Keychain; losing the phone loses the
  connections, and friends must re-add. An identity transfer during device migration is a known gap.
- **The friends layer is entirely optional.** No friends, no network, or no interest — the app is
  exactly what it was, and logging a meal still needs no network (NFR-3.2).
- **Friend data is always disposable.** If the cache is wrong, delete it and re-sync. No friend data
  is ever the only copy of anything.
- Adding a field to the stamp table is a change to this document first. What leaves the device is not
  a decision to be made at a call site.
