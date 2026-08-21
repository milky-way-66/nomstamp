# ADR-009 — Friends, again: a shared zone instead of a mesh

**Status:** accepted. **Supersedes ADR-008**, which stays in the repository as the record of why a
peer-to-peer mesh was chosen and why that choice was revisited.
**Research:** `research-friend-sync.md` — unchanged, and its verdict on Family D turns out to be the
sentence this document is built on.
**Amends CON-1, NFR-1.3, NFR-1.4 and NFR-1.5** in the SRS. **CON-2 survives intact.**

## Context: what changed

ADR-008 chose iroh, and it chose it honestly. Everything it says about identity-as-a-keypair,
about relays carrying only ciphertext, and about there being no bill, was and remains true.

What it under-weighed is in its own *The cost of no backend* section, in a sentence set aside as a
price worth paying: **two phones must be awake at the same time.**

Working through the feature's actual behaviour — a friend adds a stamp, and then what? — that
constraint stops looking like a caveat and starts looking like the feature. A reader shares a place
on Tuesday evening. Their friend is asleep. iOS will not hold a QUIC endpoint open for either of
them. The stamp waits for a moment when both applications happen to be running, on networks that
happen to be traversable, and nothing in the design can make that moment arrive.

ADR-008 named two spikes for this — OPEN-5, how often overlap happens, and OPEN-6, the direct
connection rate over Vietnamese carriers, which lean on CGNAT. Both are real, both are expensive to
run, and **neither can produce an answer that makes the problem go away.** A good result would say
the feature is often alive; it could never say the feature is reliably alive.

## Decision

**Local radio in the room, and a CloudKit shared zone afterwards. iroh is dropped entirely.**

| | |
|---|---|
| Connecting | In person only — BLE presence, a proximity gate, a matching word. No internet |
| First sync | Over the local radio link, at the table, offline |
| Every sync after | CloudKit: one custom zone per reader, shared with up to eight participants |
| Waking | `CKSubscription` silent push — the friend's device need not be awake |
| Confidentiality | Payloads sealed with our own keys **before** they reach CloudKit |
| Identity | Still an ed25519 keypair. An Apple ID is now required as well |
| Cost | Nothing. Records count against each reader's own iCloud quota, never ours |

### The thing a server actually sells

The research document put it in one line: *a server's real product is not storage or bandwidth, it
is being awake when neither person is.* That is the whole of what Family D offers and Family C
cannot, and it is the whole of what this feature needs.

A `CKSubscription` on a shared zone fires a **silent push**. The receiving phone wakes in the
background, fetches, and the stamp is on the map before the reader ever opens the app. There is no
rendezvous to arrange, because there is no rendezvous: the two devices never need to be awake
together again after the moment they met.

Silent push is the only wake mechanism iOS grants that does not depend on the other person's phone.
There is no way to obtain it without someone's server. Apple's is free.

**OPEN-5 and OPEN-6 close as no longer applicable** — not answered, not deferred. There is nothing
left for them to bound.

## Connecting: proximity is physics, not a check

The in-person rule from ADR-008 is kept in full, and every argument for it stands: a connection
should mean *you have eaten near this person*, spam becomes structurally impossible rather than
defended against, and it is the only path where the feature demonstrates itself. That was always a
**product** decision rather than a transport one, which is why it survives the transport changing
completely.

What changes is the mechanism. ADR-008 had one reader show a QR code and the other scan it, with
radio completing the handshake. That is inverted here: **radio discovers and radio carries, and the
QR becomes a fallback.**

### The rule that does the work

**No infrastructure networking anywhere in the connect path.** Not Bonjour over the local network,
not a relay, not the internet, not CloudKit.

This has to be stated as a rule because the obvious implementation breaks it. `MultipeerConnectivity`
and a plain `NWBrowser` both discover peers over the local network *as well as* over radio. Two
people on one office Wi-Fi, one campus, or one VPN would find each other from different buildings —
and anyone wanting to connect remotely need only get onto a friend's network. **The same subnet is
not the same room.**

Radio range cannot be faked. There is no software that places a phone within Bluetooth range of one
it is not near. So the enforcement is not a check we write and could get wrong; it is physics,
provided we never open a path around it.

### The four layers

1. **Presence.** CoreBluetooth advertises a service UUID, **only while the Add Friend screen is
   open**. The advertisement carries an ephemeral session id and a short name — deliberately *not*
   the public key, because a stable identifier broadcast in the clear lets anyone track a phone.
2. **The proximity gate.** An RSSI floor, tuned to mean *across this table* rather than *somewhere in
   this restaurant*. Where both devices have UWB (`NearbyInteraction`, iPhone 11 and later), real
   distance is layered on top and the ceremony becomes *hold your phones together*. This stays a
   flourish: iPhone SE has no U1, and requiring one would exclude those readers silently.
3. **The matching word.** Both phones derive the same four-letter word from a hash of the two public
   keys and show it; both readers confirm. This is not ceremony for its own sake. It answers *which
   of the four Minhs in this room*, it defends against a machine in the middle, and — the reason it
   is preferred to a scan — it is **symmetric**. Neither reader has to work out whether they are the
   one showing or the one scanning, which is where flows of this kind usually fail in practice.
4. **The exchange.** Public keys, chosen names and the `CKShare` URL travel over the local link.
   The share is accepted programmatically with `CKAcceptSharesOperation` — no link to send, no
   share sheet, and the "fiddly `CKShare` acceptance" the research document warned about does not
   arise.

**Amended, 20 August, on building it.** This ADR named `NWConnection` with `includePeerToPeer` for
step 4, and that was wrong — not slower or fiddlier, *wrong*, and in the one way this decision
cannot afford to be. A second transport has to be matched back to the Bluetooth advertisement by
some identifier, and the moment two transports are correlated by an identifier, it is the
identifier and not the radio that proves co-presence. Identifiers travel; radio range does not.
The whole argument below rests on there being no infrastructure networking anywhere in the connect
path, and step 4 would have quietly put some there.

So the exchange rides the **same** CoreBluetooth link the proximity reading came from: the key is a
GATT characteristic, read — never advertised — only by a device that has already connected, at the
reader's tap. The RSSI is re-measured on that open link rather than reused from the scan, because a
row can sit on screen for a minute while its owner walks out of the restaurant. Sixty-four bytes
over GATT is unremarkable; the guarantee is worth more than the throughput.

The first sync then runs **over that same local link**, not through CloudKit. Both readers are in the
room, so there is no round trip to make and no signal required — which matters, because the
restaurant they are sitting in probably has none.

### Why a distant connection cannot happen

| Attempt | Why it fails |
|---|---|
| Screenshot the QR and send it to another city | The code carries no connection. Keys move only over the radio leg |
| Both join one Wi-Fi network from different buildings | Nothing in the connect path uses the LAN. This is the rule above, and it is the one that is easy to break by accident |
| VPN into a friend's network | The same |
| Two accomplices relaying Bluetooth between cities | Genuinely possible — it is how car-key relay attacks work. It needs hardware at both ends, and the RSSI floor and UWB defeat most variants. Far outside this threat model |

### The naming moment

ADR-008 had the inviter confirm the request. That step lands on the phone of the person who did
nothing and may already have put it down, and it cannot really be a security gate, because the radio
leg has already proved the room.

It is re-cast as **naming**, on both devices. Each reader gets a field, pre-filled with the name the
other asserted, and whatever they type is what they will see from then on.

This is worth more than the convenience. ADR-008 spends a paragraph on the display name being
self-asserted and unverified, and defends against it by showing a key fingerprint wherever the name
is trusted. If names are **assigned locally**, the name is never trusted, because it is your own
writing — nobody else's chosen string ever renders on your device. The impersonation surface closes,
and the fingerprint returns to the friend's own screen, where it belongs, instead of following every
row around the app.

## Encrypting before it leaves

Adopting CloudKit naively would delete the strongest sentence in ADR-008: *no third party holds a
copy — not us, not Apple, not a bucket.* Advanced Data Protection makes CloudKit fields end-to-end
encrypted, but it is opt-in and off for most readers, so it cannot be leaned on.

We already generate a keypair per reader and exchange keys in person, so the payload is sealed before
CloudKit ever sees it:

- each stamp gets a random content key, and the stamp and its thumbnail are sealed with it;
- that content key is wrapped once per friend, against their public key;
- eight friends is eight wrapped keys — **256 bytes of overhead**.

Apple stores ciphertext and key blobs it cannot open, whatever the reader's ADP setting.

Two things follow. **The privacy claim survives in substance**: no third party can read a stamp or a
photograph. And this is the same per-recipient wrapping ADR-008 said a friend-of-friend mesh would
need in v2, so building it now leaves that door open rather than closed by a format change.

What genuinely leaks is **metadata**: Apple sees that two Apple IDs share a zone, roughly how large
it is, and roughly how often it changes. That is a real cost, it is smaller than the content, and it
is stated here rather than glossed.

## One zone, eight participants

Each reader owns **one custom zone**, shared once, with up to eight participants. Adding a friend
adds a participant; removing one removes them, which maps cleanly onto the cap.

Records count against the **owner's** iCloud quota. A 500-place map is about 5 MB against a 5 GB free
tier, so this is not a constraint anyone will meet.

Sharing stays per place and opt-in exactly as ADR-008 specified: a record exists in the zone only
because the reader shared that place.

## A stamp is still a place, not a meal

**The stamp table in ADR-008 is carried over unchanged and is still the most consequential thing
either document says.** One record per place, never per visit. Place name, coordinate,
`providerPlaceID`, average rating to the half star, visit count, most recent dish, month last visited
— `2026-08`, never a day — and one 240 px thumbnail. Never price, never per-meal ratings, never exact
timestamps, never full-size photographs, and notes only where the reader opted in for that place.

**Every thumbnail is re-encoded from pixels before it leaves**, and that remains a rule with its own
test rather than a line nobody reads.

Re-encoding rather than deleting the EXIF keys is deliberate: deleting named keys leaves behind
whatever the caller forgot to name — a maker note, an XMP packet, a second GPS block in an
app-specific segment. Starting from a bare `CGImage` means the only thing in the output is what the
encoder put there.

What the encoder puts there is worth stating precisely, because the first version of this rule was
wrong. ImageIO writes an EXIF dictionary on every JPEG it encodes, holding the colour space and the
image's own pixel dimensions; no setting suppresses them, and they are facts about the file rather
than about the reader. So the rule names what is **forbidden** — GPS, TIFF, IPTC, ExifAux and
maker-note blocks, and any EXIF key beyond the geometry — instead of claiming an absence the encoder
cannot deliver. A rule that cannot be honoured is one that gets quietly weakened later.

Two refinements the sync behaviour makes necessary:

- **The projection is recomputed on every underlying change, not when the share toggle is flipped.**
  If a reader eats somewhere again, the visit count and average move; a version that does not follow
  leaves every friend holding a stale copy that presents itself as current.
- **Versions come from a content hash of the projection.** Because the stamp is coarsened — a month,
  not a date; an average, not a list — most edits change nothing that travels. Correcting an unshared
  note, or adding a photograph that is not the pin photo, produces no hash change, no version bump
  and no traffic. It is a small rule that removes most resynchronisation, and it is pure domain logic.

## A friend's ink

Each friend's ink is still derived deterministically from their public key, selecting from a curated
set of **eight**, with the next free ink used where one is taken: local uniqueness beats cross-device
stability, because a map where two friends share a colour fails at the only job the ink has.

Two things ADR-008 left unresolved are settled here.

**The eight inks are a fixed plate, exempt from the skin.** ADR-006 rotates the app's accents with
the weather and the day, but its own principle is that some things are constant so that what a reader
reads never moves — the page, the body ink, the rating ramp. **A friend's identity belongs in that
class.** If Lan changed colour when it rained, the ink would stop being an identity. The eight are
drawn from the same pigment family the five skins are drawn from, so a fixed plate still reads as
this journal's box of inks rather than a foreign object on the page.

This also collapses a constraint that looked severe. Eight inks do not have to stay distinct from
`visitedInk` and `wishlistInk` across five skins, because **colour is not what answers *mine or
theirs*** — the cut does. The reader's own stamps keep a solid edge and friends' carry a perforated
one (NFR-6.3). Hue only has to answer *which friend*, so the eight need to be mutually distinct and
clear the AAA floor TC-N-07 enforces over paper, in light and dark, and nothing more.

**A pin is drawn with at most one countersignature.** ADR-008 describes *a second, smaller stamp*,
in the singular, and never says what a place five friends have all stamped looks like. At pin size
five overlapping stamps are the box of crayons the cap exists to prevent. So: the reader's own stamp,
one countersign, and a small numeral in `printingInk` for the rest. Which friend is drawn is decided
by lowest occupied ink slot rather than by recency, so the pin does not change under the reader
between one sync and the next. The full list belongs on place detail, where there is room to name
people.

## What the reader sees when a stamp arrives

**No notifications.** A silent push wakes the app, never the person. A local notification would sell
an immediacy the feature does not want to promise, and would turn a slow journal into a feed.

**A new stamp arrives freshly pressed and fades.** Stamps received since the reader last looked carry
a heavier press, decaying to ordinary over a few days. It is the metaphor doing real work, it costs
no traffic, and it degrades correctly: a reader who stays away for a month returns to a page of
ordinary stamps rather than two hundred unread badges.

**Staleness is per friend, not per stamp.** If Lan was last reached on 12 August then every stamp of
hers is as of 12 August, including ones untouched since June. The date belongs to the friend — on the
friends screen and the layer control — and never on a pin, where it would imply a per-stamp recency
we do not have.

**Absence is unprovable, and the copy must obey it.** Retraction propagates on the next connection
and no sooner, so the interface may say *twelve places, as of 12 August* and may never say *Lan
shares twelve places*. ADR-008 admits retraction is best-effort; this carries that admission into the
wording.

**The event worth surfacing is not a new stamp but a countersignature.** *You and Lan have both eaten
at Bún Chả Hương Liên* is the same data as a count of new stamps, needs no extra transport, and is
the only version of it a person would repeat to someone else. It leads the friends screen.

## What this costs the promise

**CON-1 is amended.** *No backend, no server, no user accounts* becomes **no backend we run**. We
write, deploy and operate nothing, and that half is unchanged. But an Apple ID signed into iCloud is
now required, and ADR-008's proudest sentence — *the identity is a key the device generated and
nobody registered* — is no longer true on its own. The keypair still exists and still does the
cryptographic work; it is simply no longer the only account involved.

**CON-2 survives untouched.** No paid API, no key shipped, no bill, no plan to upgrade. Private and
shared database usage is charged to each reader's own iCloud quota, never to a developer account.
This is why the public database is not used anywhere in this design.

**CON-4 hardens from a choice into a permanence.** iPhone-only was previously a decision that could
have been revisited; CloudKit closes the door. iroh was cross-platform, and an Android build could
have joined the same mesh. That costs nothing today and cannot be undone later.

**NFR-1.3** widens to include CloudKit. **NFR-1.4** is amended: an account is required, though no
identifying data is collected by us. **NFR-1.5** is amended from *no third party holds a copy* to
**no third party can read what it holds** — the sealing above is what keeps the substance of it.

## Layering

CloudKit is a framework, and therefore never appears in the domain (CON-5, NFR-7.1). The layering
from ADR-008 is carried over **unchanged**, which is the design earning its keep: `StampSyncPort` and
`BlobStorePort` were specified so the transport could be replaced without the domain noticing, and
replacing the transport has not touched the domain.

| Where | What |
|---|---|
| `FoodMapDomain/Entities` | `Friend`, `FriendStamp`, `SharedStamp`, `StampManifest` |
| `FoodMapDomain/UseCases` | `BuildSharedStampUseCase` — the projection, the redaction rules and the content hash |
| | `ReconcileManifestUseCase` — the diff, with no network in sight |
| | `MergeFriendStampsUseCase` — matching, countersign resolution |
| `FoodMapDomain/Ports` | `PeerIdentityPort`, `StampSyncPort`, `BlobStorePort`, `ProximityPort` |
| `FoodMapData/Sharing` | CloudKit zone and share, subscriptions, sealing, EXIF stripping, Keychain |
| `FoodMapData/Proximity` | CoreBluetooth presence, RSSI gate, the GATT key exchange, `NearbyInteraction` |

The rule about **what may leave the device** still lives in the domain, unit-tested on macOS in under
five seconds with no simulator and no network. A redaction rule buried in a transport adapter is a
rule nobody can prove.

## Consequences

- **A whole class of defect disappears.** Half-open connections, a peer that vanishes mid-fetch,
  partial manifests, hole-punching failures — ADR-008 listed these as needing test cases before
  anything could be built. CloudKit handles them, and they stop being ours.
- **The Rust FFI dependency is gone**, and with it the binary-size, build-reproducibility and CI
  questions ADR-008 could only mark as needing measurement.
- **Battery improves.** No QUIC endpoint to hold open, no relay connection. What remains is
  foreground BLE during the connect ceremony, which is bounded by a screen being open.
- **A new failure mode arrives: no iCloud account.** A reader signed out of iCloud cannot use the
  feature at all. This must read as an explanation with a way forward, never as an error, and the
  rest of the app must be entirely unaffected — logging a meal still needs no network and no account.
- **Background push delivery is not guaranteed.** iOS throttles silent pushes by how much the app is
  used, so a reader who rarely opens it will see stamps arrive later. This is far better than
  requiring simultaneous wakefulness, and it is still not a delivery guarantee. The interface keeps
  ADR-008's honesty about staleness for exactly this reason.
- **A new device keeps the connections but not the identity.** The Apple ID carries the share
  membership across a device migration, but the ed25519 private key lives in the Keychain. Keychain
  transfer during migration needs verifying rather than assuming; if it fails, friends must re-add.
- **Friend data is still disposable.** If the cache is wrong, delete it and re-fetch. No friend data
  is ever the only copy of anything — with one candidate exception, OPEN-10 below.
- **The friends feature is still entirely optional.** No friends, no account, or no interest, and the
  app is exactly what it was.
- Adding a field to the stamp table is a change to this document first. What leaves the device is not
  a decision to be made at a call site.

## Open

| ID | Question |
|---|---|
| OPEN-8 | Whether locally-assigned names fully replace FR-10.6's fingerprint-wherever-the-name-is-trusted rule, or whether the fingerprint stays somewhere in the everyday interface |
| OPEN-9 | Whether the bulk share joins the connect ceremony. Nothing is shared by default, so a first connection otherwise lands an empty layer at the table — the dead first impression the in-person rule exists to avoid, arriving through another door |
| OPEN-10 | Whether the fresh-ink decay is worth its cost. It needs a per-stamp *first seen* date, which is the first piece of friend data not reconstructible by re-syncing, and FR-13.4 says friend data is a disposable cache |
| OPEN-11 | How reliably a silent push wakes the app for a shared-zone change when it has not been opened in days. This is the value proposition, and it is cheap to measure |
| OPEN-12 | `quotaExceeded` behaviour for readers who are non-primary members of a Family iCloud plan — flagged in the research document, and it would fail for the zone's owner rather than its participants |
| OPEN-13 | The RSSI threshold that reliably means *across this table* and not *across this restaurant*. The proximity claim rests on this number, and it is an afternoon's measurement. Moved from -55 to **-70** on the first two-device trial: -55 refused two phones on the same table once a hand was between them. Still a guess, still a spike |
