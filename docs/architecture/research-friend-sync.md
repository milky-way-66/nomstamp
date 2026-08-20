# Research — how two phones share stamps

**Status:** research, complete. **Decision taken in ADR-008: iroh** — Family C, direct peer to peer.
**Date:** 2026-08-20

Two problems, independent of each other, usually conflated:

1. **Rendezvous** — how does my phone reach my friend's phone at all?
2. **Payload** — how does a photograph get across, cheaply?

The second turns out to be much smaller than it looks, so it is answered first.

---

## Problem 2 first: the image problem is mostly not a transport problem

Three levers, applied in this order, before any transport is chosen:

| Lever | Effect |
|---|---|
| **Which image** — 240 px thumbnail, not the 2048 px original | ~500 KB → ~15 KB, a **30×** cut |
| **Which codec** — HEIC or AVIF rather than JPEG at that size | ~15 KB → **~7 KB**, iOS encodes HEIC natively |
| **When** — fetch on demand as a pin scrolls into view, not eagerly with the record | most friend pins are never opened at all |

Run the numbers on a whole person:

```
500 stamped places × ~10 KB thumbnail  ≈  5 MB
```

**An entire lifetime food map, in pictures, is about five megabytes.** That fits in one AirDrop, one
QUIC stream, one email attachment, and inside every free tier on the market with room to spare. Once
thumbnails are the decision, "how do we move the images" stops being the hard question.

Originals are the only thing that is genuinely expensive, and they are only wanted when someone
opens a specific place — which is a rare, explicit, one-at-a-time act, well suited to fetch-on-demand
over whatever channel already exists.

### Where the bytes can live

| Approach | Storage cost to us | Notes |
|---|---|---|
| **Inline in the payload** | none | Bundle thumbnails into the file or stream. No storage anywhere |
| **`CKAsset`** (CloudKit) | none | Counts against each reader's own iCloud quota |
| **`iroh-blobs`** | none | Content-addressed BLAKE3 blobs, resumable, dedupe built in, peer to peer |
| **`sendResource`** (MultipeerConnectivity) | none | File transfer with progress, built in, proximity only |
| **Object storage** (R2, Firebase, Supabase, S3) | ours | R2 is the strongest: 10 GB free, **zero egress**, no card |

Two cross-cutting techniques worth applying whatever is chosen:

- **Content addressing** — name a blob by its hash, fetch once, cache forever, never re-fetch. Makes
  re-sync and multi-device nearly free.
- **Encrypt before it leaves.** If thumbnails are encrypted on the device, storing them on
  infrastructure we do not own becomes far more defensible — the host holds ciphertext it cannot read.

---

## Problem 1: rendezvous. Five families

### Family A — proximity: same room, no internet at all

| Option | Reality |
|---|---|
| **Wi-Fi Aware** (iOS 26, new) + `DeviceDiscoveryUI` | Apple's modern peer-to-peer, opened up under the EU DMA so third parties can build AirDrop alternatives. High speed, no access point needed, and an **open standard** — Android-compatible in principle |
| **MultipeerConnectivity** | Still works, not formally deprecated, but ageing: built on `NSStream`, no flow control, obsolete UI components, an awkward PKI security model, and it always switches on peer-to-peer Wi-Fi |
| **Network.framework + Bonjour** | Same-LAN discovery and connections. More control, more code |
| **CoreBluetooth** | Kilobytes per second. Fine for exchanging an identity, hopeless for images |

**Verdict:** charming — *we ate together, so we swap stamps* — and genuinely zero-infrastructure.
Useless for a friend in another city, which is most friends.

### Family B — sneakernet: the reader carries the file

| Option | Reality |
|---|---|
| **Share sheet → Messages, Zalo, AirDrop, email** | Export a file, friend taps it, app imports. Works at any distance, forever, for nothing |
| **QR code** | ~3 KB maximum. Enough for an identity or an invitation; not for data |
| **Universal link** | ~2 KB practical. Invitations only |

**Verdict:** the only family with *no* moving parts and no dependency that can be withdrawn. The cost
is that it ships snapshots, not updates, and unsharing cannot retract what was already sent.

### Family C — peer-to-peer over the internet

| Option | Reality |
|---|---|
| **iroh** | 1.0 shipped. **Dial a peer by its public key, not its IP** — which is exactly the device-identity model. QUIC transport, ~90% direct hole-punch, **95–99%** overall using free rate-limited public relays run by n0; relays are stateless and see only encrypted bytes. **Official Swift bindings** for iOS via uniffi. `iroh-blobs` handles the images |
| **WebRTC** | Needs a signalling channel to exchange offers — that is a server, unless hand-signalled via QR or Messages. Plus TURN relay for the 10–20% where NAT traversal fails, and TURN bandwidth is expensive |
| **Nostr** | Identity **is** a keypair; free public relays; signed events. But relays are volunteer-run and can rate-limit, drop or vanish, and they do not host images |
| **Ditto** | Real mesh sync SDK — BLE, peer-to-peer Wi-Fi, LAN, plus an optional cloud bridge. Swift SDK. Commercial, free-tier terms not public, vendor lock-in |

**Verdict:** iroh is the only option in this whole document that delivers *live, any distance, no
backend we run, identity as a keypair* simultaneously. It deserves a spike.

### Family D — someone else's backend, not ours to run

| Option | Reality |
|---|---|
| **CloudKit** | Live sync, `CKAsset` for images, free against each reader's own iCloud quota, no auth to build. Costs: Apple ID required, iPhone-only forever, fiddly `CKShare` acceptance, known `quotaExceeded` edge case for non-primary Family plan members |
| **iCloud Drive shared folder** | Almost no code. The sharing UX is user-driven and clumsy |
| **BYO-cloud** — reader's own Dropbox or Google Drive via OAuth | Free to us entirely. Needs OAuth and shipped client keys, which collides with CON-2 |

**Verdict:** honest label is *a backend, just not ours*. CloudKit is much the strongest of these.

### Family E — a backend we actually run

| Option | Reality |
|---|---|
| **Cloudflare R2 + Workers + D1 + Durable Objects** | Best-value of the three by a distance: R2 gives 10 GB and **zero egress** with no card; Workers 100k req/day; D1 5 GB; Durable Objects now on the free plan **with WebSockets** for realtime |
| **Supabase** | 1 GB storage, 5 GB egress *per project, not per user*; free projects **pause after 7 quiet days** |
| **Firebase** | Since **3 Feb 2026** Cloud Storage needs a Blaze billing account — no bucket at all on Spark |

**Verdict:** viable and cheap, but it is a second codebase in a second language, plus auth, plus
security rules that must be perfect, plus legal custody of other people's photographs and movement
history. R2 credentials cannot ship in the app (CON-2), so a Worker in front is mandatory, and the
moment that Worker exists we are operating a server.

---

## The axis that actually decides it: does it work when your friend's phone is asleep?

This cuts across everything above and is the question most easily missed.

| | Both devices awake at once? |
|---|---|
| Proximity (Family A) | **Required**, and in the same room |
| P2P over internet — iroh, WebRTC (Family C) | **Required** |
| Sneakernet (Family B) | Not required — but not live either |
| CloudKit, any server (Families D, E) | **Not required** — store-and-forward |

A server's real product is not storage or bandwidth. It is **being awake when neither person is**.
That is the whole of what Families D and E sell that Family C cannot.

The question that follows is a product question, not a technical one: *for a food journal, does that
matter?* A chat app needs store-and-forward. A record of where someone ate lunch three weeks ago
arguably syncs perfectly well the next time both people happen to open the app. If the answer is
"good enough", iroh becomes viable and no backend is needed by anyone. If the answer is "stamps must
appear while I am not looking", the choice narrows to CloudKit or a server we run.

## One simplification worth banking whatever is chosen

**No CRDT is needed.** Merge machinery — Automerge, Yjs, Loro, cr-sqlite — solves concurrent edits to
shared state. Nobody ever edits a friend's stamp. Friend data is strictly read-only, single-author,
so per-place records versioned by their author with last-write-wins is correct and is a fraction of
the work.

## Open, and worth a spike before deciding

1. **iroh on iOS**: battery cost of holding an endpoint, behaviour under background execution limits,
   binary size of the Rust FFI, and how often the "both awake" constraint actually bites in practice.
2. Whether **Wi-Fi Aware** is worth pairing with any online option as a fast path for the
   we-are-at-dinner-together case.
3. Whether a **hybrid** is the honest answer: sneakernet or iroh for the connection, CloudKit only as
   the store-and-forward mailbox.
