# Checking the radio, without two phones

TC-8-12 — *two stubbed devices in range* — is the one case in this project that no test process can
supply, and it is the case that matters most: the connect ceremony is the only path into the
friends feature, and every layer of it can be green while no phone has ever seen another. That is
not hypothetical. It happened. The ceremony shipped with nothing calling `BluetoothPresence.begin()`
and 240 passing tests said nothing about it.

**A simulator cannot help here.** Not "is awkward" — cannot. CoreBluetooth inside the iOS Simulator
reports `unsupported` (raw value 2) and logs `[CoreBluetooth] XPC connection invalid`: there is no
`bluetoothd` behind it. Nothing advertises, nothing scans, and `CBCentralManager` never reaches
`poweredOn`. Any plan that involves two simulators finding each other is a plan that cannot work.

What *is* available before you find a second iPhone is a Mac. It has a real radio, and
`Tools/PeerProbe.swift` turns it into a second reader.

## Listening — does the phone actually advertise?

```
swift Tools/PeerProbe.swift listen
```

Then open **Add friend** on the phone. Within a second or two the Mac should start printing:

```
[14:02:11] Long's iPhone            -48 dBm  PASSES the gate  — name in this packet, packet #1
[14:02:11] Long's iPhone            -49 dBm  PASSES the gate  — name from an earlier packet, packet #2
```

That single screen answers most of the open questions at once:

- **anything at all** — the advertisement is going out, and `begin()` is being called;
- **the name column** — the name is arriving, and the *"from an earlier packet"* lines are the
  advert/scan-response split that `PresenceRegistry` exists to survive (TC-8-17). Seeing both kinds
  is the confirmation; seeing only nameless ones means the name never fits and the phone would have
  vanished from the list under the old code;
- **the dBm column** — this is the OPEN-13 instrument. Put the phone where a friend would hold it,
  then walk to the next table, then across the room, and read where the numbers land. The verdict
  column judges each reading against `ProximityProof.signalFloor`, so the floor can be set from
  observation instead of from a datasheet;
- **closing the screen stops the printing** — which is FR-10.11, discoverable only while the screen
  is open, checked from outside the app rather than asserted from inside it.

Nothing printed at all means the phone is not advertising. Check that Bluetooth is on, that the
Bluetooth permission was granted the first time *Add friend* opened, and that the screen is the one
actually open.

## Advertising — does the phone find and read a peer?

```
swift Tools/PeerProbe.swift advertise
```

**Probe Mac** should appear in the phone's list. Tapping it should print, on the Mac:

```
[14:05:32] a phone connected and read the key — the exchange works
```

and take the phone to the four-letter matching word. That exercises scan → connect → discover
service → discover characteristic → read, which is every step of the exchange except that the key
came from a Mac rather than another Nomstamp.

`both` runs the two modes together, which is what a phone does.

## What this still does not prove

The probe is written against CoreBluetooth directly and shares no code with the app, deliberately: a
harness built on `BluetoothPresence` would inherit its bugs and confirm them. But a Mac is not a
phone, and three things stay open until two iPhones are in a room:

- **symmetry** — that both readers see each other, and derive the *same* four letters. The Mac
  offers a fake key, so the word it produces is meaningless;
- **the floor, properly** — a Mac's transmit power is not an iPhone's. Readings here are the right
  order of magnitude, not the number to ship;
- **the whole ceremony**, end to end, with two people naming each other. That is TC-8-12, and it
  stays manual.

## First run

macOS will ask the terminal for Bluetooth the first time. Say yes; the probe prints
`This terminal has not been allowed Bluetooth` if it was refused. A run that stops after the header
and never says `listening` is usually that permission, still unanswered behind another window.
