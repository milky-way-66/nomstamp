# ADR-011 — The camera is the product, so it should be a camera

**Status:** accepted. **Extends FR-1** in the SRS with a new group, **FR-14 Capture**.
Does not amend ADR-005 (art direction) — the camera stays black-ground and undecorated, because a
viewfinder is the one screen in the app that is not made of paper.

## Context: one shutter, and nothing else

`InAppCamera.swift` was written to settle a different question — whether to use the system picker
or our own — and it settled it correctly. Photographing food is the core loop (UC-1, FR-1.10), and
handing it to a stock sheet made it feel like a detour. What was built is a live preview, one
shutter, one way out, and a library button beside it. It has been enough to prove the flow.

It is not a camera. Reading `AVCaptureDevice.default(for: .video)` — the single line the whole
session is built on — the following are all true:

- **There is no front camera, and no way to reach one.** `default(for: .video)` returns the back
  wide-angle device, and nothing in the app ever asks for another. The reader cannot photograph
  themselves at the table, and cannot photograph a friend across it. This was the first thing
  anyone using it noticed, and it is the reason this ADR exists.
- **There is no lens choice at all.** No ultra-wide, no telephoto, and — most costly for this app
  specifically — **no macro.** A bowl of bún chả photographed at arm's length on the wide lens is
  the single most common shot the app will ever take, and it is exactly the shot where a modern
  iPhone switches to the ultra-wide's close focus. We opt out of that by construction.
- **There is no zoom, no tap to focus, and no tap to expose.** A dish on a dark table under a warm
  light is a hard exposure, and the reader has no way to tell the camera which part of the frame
  is the food.
- **There is no torch.** The app has a *night market* appearance (ADR-003) and no way to light a
  bowl of noodles at one.
- **Orientation is never set on the capture connection.** It defaults to portrait, so a photograph
  taken with the phone turned sideways is written with portrait orientation metadata. This is not a
  preference; it is a bug, and it silently damages stored photographs.
- **A failed capture is silent.** `guard let data = photo.fileDataRepresentation() else { return }`
  — the delegate returns, no callback fires, and the reader sees a shutter that did nothing
  (`InAppCamera.swift:99`). NFR-4.4 requires an error to say what happened; this one says nothing.
- **The shutter gives no feedback.** No haptic, no flash, no sound. On a device whose shutter is a
  drawn white circle rather than a physical button, nothing confirms the photograph was taken.

The last three are defects against requirements the app already holds itself to. The rest are the
gap between *a preview with a button* and *the thing this product is for*.

## Decision

The camera becomes a camera, in the order the shots are actually taken.

### 1. Both cameras, and the right lens

The session gains a **front/back flip**. The back camera is discovered as
`builtInTripleCamera → builtInDualWideCamera → builtInWideAngleCamera`, taking the first that
exists, so that on any phone with an ultra-wide the system's **automatic macro switching** is
available and close-ups of food focus instead of hunting. The front camera is
`builtInTrueDepthCamera → builtInWideAngleCamera`.

Flipping is a labelled control beside the shutter, and the chosen side **does not persist** between
meals: the next meal opens on the back camera, because that is what a meal is. Photographing the
table is the exception, and an exception should cost one tap rather than being sticky.

*Why discovery rather than `default(for:)`:* `default(for: .video)` is documented to return the
wide-angle device, which is precisely the device that cannot focus close. The one-line convenience
is the cause of the macro problem, not merely adjacent to it.

### 2. Zoom, focus and exposure

- **Pinch to zoom**, clamped to the device's `videoMaxZoomFactor`, plus a **1× / 2× tap** where the
  device offers it.
- **Tap to focus and expose**, at the tapped point, drawn as a brief square on the preview. Both
  `focusPointOfInterest` and `exposurePointOfInterest` are set from one tap: a reader who taps the
  food means *that is the subject*, and separating the two would be a photographer's distinction,
  not a diner's.
- Tapping again, or flipping the camera, returns to continuous auto.

### 3. Light

A **torch control**, three-state — off, on, auto — where the device has one, defaulting to off and
not persisting. Flash on food is usually a worse photograph than the ambient light, so it is
offered rather than assumed. The control is hidden entirely on devices with no torch, rather than
shown disabled.

### 4. Orientation

The capture connection's rotation angle is set from the device orientation at the moment of
capture, via `AVCaptureDevice.RotationCoordinator` where available. A photograph taken sideways is
stored the way it was taken. **This is a correctness fix, and the only part of this ADR that
changes photographs already describable as broken.**

### 5. The shutter answers

Every capture produces feedback before the photo is processed: a **haptic** and a brief
**viewfinder dim**. A capture that fails produces a message — *That shot didn't come through. Try
again.* (see the voice note, 21 Aug) — rather than nothing at all.

### 6. What is deliberately not built

- **No filters, no grid, no level, no timer, no burst.** The app is not a camera app; it is a
  notebook that needs one good photograph.
- **No video.** A meal is a photograph. Nothing in the domain models a duration.
- **No RAW.** NFR-8.1 caps stored images at 2048 px; RAW would be discarded on the next line.
- **No custom exposure or white-balance sliders.** Tap-to-expose covers the case; sliders are for a
  reader who has already decided the camera is the product.

## Consequences

**Good.** The most common photograph in the app — a dish, close, in poor light — becomes the one
the camera is set up for rather than the one it handles worst. The front camera exists. Sideways
photographs stop being written wrong. Three violations of NFR-4.4, NFR-3.3 and FR-2.3 close.

**The cost.** `CameraSession` roughly doubles: device discovery, a reconfiguration path for
flipping, focus/exposure/zoom state, torch state, and rotation. It stays one file and stays in the
app target, since it is an adapter over AVFoundation with no domain content — consistent with
NFR-7.1, which keeps AVFoundation out of the domain, and unchanged by this decision.

**What cannot be tested in CI.** `CameraSession.isSupported` is false on every simulator, so none
of this runs in the e2e suite. The testable part is the **device-selection policy** — given a set
of available device types, which is chosen, front and back — which moves into a small pure type in
the app target and is unit-tested. Everything else is a manual check on a device, recorded as
TC-1-31 (manual), in the same way TC-8-12 records the radio path.

**The simulator path stays.** `.unavailable` still renders its message and the library button still
works, so the UI journeys are unaffected.

## Alternatives considered

**Keep the system camera picker.** Rejected once already (FR-1.10, and the comment at the top of
`InAppCamera.swift`); it gives all of the above for free and takes the flow's shape away in
exchange. The camera opening on the first frame is the reason logging a meal is three taps.

**Adopt `AVCaptureDevice.systemPreferredCamera`.** Tempting for the flip, but it follows the
system's idea of a preferred camera, which is not this app's — it does not know that a meal is
almost always a back-camera close-up.

**Ship the orientation fix alone and defer the rest.** The orientation bug is the only true defect
of the six, and could be a one-line change. Rejected because the front camera is what was actually
asked for, and because the device-discovery change that fixes macro is the same change that makes
the flip possible. Splitting them means writing the discovery code twice.
