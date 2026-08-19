# Shipping Nomstamp — TestFlight, then the App Store

From an empty App Store Connect account to a build testers can install, and from there to a
public release. Written for this repository as it stands on 19 August 2026: XcodeGen, Xcode 26.3,
iOS 18 deployment target, bundle identifier `com.longnv.foodmap.app`.

Read it once end to end before starting. Steps 1–3 are one-off setup; steps 4–8 are the loop you
repeat for every build.

---

## 0. What must change in the repository first

Two things in this checkout prevent a distributable build. Neither is a mistake — both were
deliberate choices for a simulator-only project — but both must be undone before Apple will
accept an upload.

### 0.1 Code signing is switched off

`project.yml` currently carries, in `settings.base`:

```yaml
CODE_SIGNING_REQUIRED: NO
CODE_SIGNING_ALLOWED: NO
```

That is what lets `xcodebuild` produce a simulator app with no developer account. An archive for
the App Store must be signed. Keep the simulator convenience for Debug, and require signing for
Release:

```yaml
settings:
  base:
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
  configs:
    Debug:
      CODE_SIGNING_REQUIRED: NO
      CODE_SIGNING_ALLOWED: NO
targets:
  FoodMap:
    settings:
      base:
        # …existing keys…
        DEVELOPMENT_TEAM: ABCDE12345          # your ten-character Team ID
        CODE_SIGN_STYLE: Automatic
        # No encryption beyond Apple's own — see §5.4. Declaring it here means
        # App Store Connect never asks again, for any build.
        INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO
```

Your Team ID is on <https://developer.apple.com/account> under *Membership details*.

Re-run `xcodegen generate` afterwards. **Every** change to `project.yml` needs it; the `.xcodeproj`
is generated, so editing signing settings in Xcode's UI is thrown away on the next generate.

### 0.2 The app icon

Done — `FoodMap/Resources/Assets.xcassets/AppIcon.appiconset` holds a single 1024×1024 PNG, sRGB
and **without an alpha channel** (App Store Connect rejects transparency). A single size is
sufficient on iOS 18+; the system derives the rest.

The icon is the app's own motif: a perforated stamp in paper white on pandan green, with the
printing ink a shade off register behind it and the fork-and-knife glyph a visited pin carries
(ADR-005). It is generated, not hand-drawn, so the palette can never drift from `Palette.swift`:

```bash
swift Tools/MakeAppIcon.swift FoodMap/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is already set on the target. If you replace the
icon by hand, keep it square, opaque, and free of rounded corners — iOS masks it itself.

### 0.3 Decide the version and build number

- `MARKETING_VERSION` (`1.0`) is what users see. Bump for each public release.
- `CURRENT_PROJECT_VERSION` (`1`) is the build number. **It must increase for every single
  upload**, even a re-upload of the same version after a rejection. App Store Connect refuses a
  duplicate outright, and you cannot delete and retry.

A simple habit: leave `MARKETING_VERSION` alone during a testing round and increment
`CURRENT_PROJECT_VERSION` on each upload — 1.0 (1), 1.0 (2), 1.0 (3).

---

## 1. Apple Developer Program — the one-off account work

You already have the account, so this is a checklist rather than a tutorial.

1. **Agreements.** In App Store Connect → *Business*, the Paid Applications agreement is only
   needed for paid apps; the free-app agreement must be *Active*. Nothing uploads until it is.
2. **Roles.** You need Account Holder, Admin, or App Manager to create an app record, and Admin or
   App Manager to manage TestFlight.
3. **Certificates and profiles.** Let automatic signing manage these. There are two ways to give
   it an identity to work with, and `scripts/deploy.sh` needs neither Xcode open:

   - **API key (what the script uses).** The App Store Connect key in `.env` is passed to
     `xcodebuild` as `-authenticationKeyPath/-ID/-IssuerID`, so `-allowProvisioningUpdates` can
     issue the distribution certificate and download the profile by itself. The key must hold the
     **App Manager** role — a Developer-role key can upload but cannot create a certificate.
   - **A signed-in Apple ID.** Xcode → *Settings* → *Accounts*, add your Apple ID, select the team,
     *Manage Certificates* → **+** → *Apple Distribution*. Needed only if you archive from the
     Xcode UI rather than the script.

   With neither, an archive fails at once with *No Accounts: Add a new account in Accounts
   settings* followed by *No profiles for `com.longnv.foodmap.app` were found*.

### 1.1 Register the bundle identifier

Usually automatic, but do it explicitly so the ID is certainly yours:

<https://developer.apple.com/account/resources/identifiers> → **+** → *App IDs* → *App* →

- Description: `Nomstamp`
- Bundle ID: **Explicit** → `com.longnv.foodmap.app`
- Capabilities: leave everything off. Nomstamp has no push, no iCloud, no sign-in, no backend
  (SRS: no account, no server). Camera, photo library, and location need only the usage strings
  already in `project.yml`, not entitlements.

The identifier still says `foodmap` while the app is called Nomstamp, and that is fine — nobody
outside the developer account ever sees a bundle ID. It is under `com.longnv`, a prefix nobody else
can claim, so registration will not collide. The UITest target's identifier
(`com.longnv.foodmap.app.uitests`) is never uploaded and needs no registration.

Change it now if the mismatch will bother you later — `com.longnv.nomstamp.app`, plus the UI-test ID
beside it, then `xcodegen generate`. **After the first upload it is permanent**: a new bundle ID
means a new app record, and existing installs cannot migrate to it. The store name, by contrast,
you can change whenever you like.

The bundle ID is permanent once a build is uploaded against it. The **store name** is not — you can
rename Nomstamp later without touching the identifier.

---

## 2. Create the app record in App Store Connect

<https://appstoreconnect.apple.com> → *My Apps* → **+** → *New App*.

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `Nomstamp` — 30 characters max, unique across the entire store. Check it is still free before saving |
| Primary language | English (U.S.) — Vietnamese is added later as a localisation |
| Bundle ID | `com.longnv.foodmap.app` (pick from the list; it appears once registered) |
| SKU | Any private string, e.g. `NOMSTAMP-001`. Never shown to users, never changeable |
| User access | Full Access |

The name is claimed the moment you save it, held for the app for 90 days if unused.

Because the app ships Vietnamese (NFR-5.1), add the localisation now: on the app's *Distribution*
page, the language selector at the top-left → *Add Language* → Vietnamese. You then fill in name,
subtitle, description, and keywords in both languages.

---

## 3. Archive and upload the first build

TestFlight has no separate build path — you upload one archive, and the same binary can go to
testers and then to review.

### 3.1 From Xcode (recommended for the first time)

```bash
xcodegen generate
open FoodMap.xcodeproj
```

1. Scheme selector → **FoodMap**, destination → **Any iOS Device (arm64)**. Archive is greyed out
   for simulator destinations.
2. *Product* → *Archive*. The Organizer opens when it finishes.
3. Select the archive → *Distribute App* → **App Store Connect** → *Upload*.
4. Accept the defaults: *Upload your app's symbols* (yes — you want readable crash reports),
   *Manage Version and Build Number* (leave **off**; keep the numbers under `project.yml`'s
   control so the repository stays the source of truth).
5. *Automatically manage signing* → Next → Upload.

### 3.2 From the command line (for repeats)

[`scripts/deploy.sh`](../../scripts/deploy.sh) does everything below in order, and refuses rather
than half-finishes when something is missing:

```bash
cp .env.example .env               # then fill in the three values it explains
$EDITOR .env

scripts/deploy.sh --dry-run        # see the whole plan, touch nothing
scripts/deploy.sh --bump           # bump the build number, test, archive, export, upload
```

`.env` is gitignored, and the script refuses to run if it ever becomes tracked. Anything already in
the environment beats the file, so a one-off override needs no edit:

```bash
ASC_TEAM_ID=OTHER12345 scripts/deploy.sh --no-upload
```

It generates the project, runs all four suites, archives Release, exports, uploads, and tags the
commit as `v<version>-<build>` when the working tree is clean. `--skip-tests` when the suites just
ran; `--no-upload` to stop after the export. Run `scripts/deploy.sh --help` for the rest.

The steps it performs, should you ever need them by hand:

```bash
xcodegen generate

xcodebuild -project FoodMap.xcodeproj \
  -scheme FoodMap \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Nomstamp.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/Nomstamp.xcarchive \
  -exportOptionsPlist docs/deployment/ExportOptions.plist \
  -exportPath build/export

xcrun altool --upload-app -f build/export/FoodMap.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

`docs/deployment/ExportOptions.plist` is the committed reference copy, with a placeholder team ID;
the script writes its own from `$ASC_TEAM_ID` into `build/` so no real identifier is committed.

The API key comes from *Users and Access* → *Integrations* → *App Store Connect API* → **+**, role
*App Manager*. Download the `.p8` **once** — it cannot be downloaded again — and put it in
`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`, which is where the uploader looks. Never
commit it. `xcrun notarytool` is for Mac apps; iOS uploads do not need notarisation.

### 3.3 Processing

The build appears in App Store Connect → *TestFlight* within a few minutes, marked *Processing*,
and usually becomes available in five to thirty minutes. If it never appears, check the email
Apple sends to the account holder — invalid binaries are rejected silently in the UI but always
explained by email.

Common first-upload rejections:

- **Missing app icon** — §0.2.
- **Icon has alpha** — flatten the PNG.
- **Invalid bundle: unsupported architecture** — you archived for the simulator.
- **Missing usage description** — not an issue here; all three strings are in `project.yml`.

---

## 4. TestFlight — internal testing

Internal testers get builds immediately with **no App Review**. This is where you will spend the
testing round.

1. *TestFlight* → *Internal Testing* → **+** beside *Internal Group* → name it `Team`.
2. Add testers by Apple ID. Anyone you add must first exist under *Users and Access*; up to 100
   people, each on up to 30 devices.
3. Tick *Automatically distribute builds* so every future upload reaches them without a click.
4. Testers install the **TestFlight** app from the App Store, accept the email invitation, and the
   build appears there.

Before the first build is testable, App Store Connect asks for **Test Information**: an email
address for feedback, and *What to Test* notes. Fill in what changed — testers see it in
TestFlight.

Builds expire after **90 days**.

### 4.1 External testing (optional)

Up to 10,000 testers, invited by email or a public link. Requires a **Beta App Review** for the
first build of each version — typically under 24 hours, and much lighter than a full review, but it
does check the app runs and matches its description. Later builds of the same version usually skip
it.

Use this only if you want testers outside your own team. For a private app, internal testing is
enough.

### 4.2 What to actually test on device

The simulator cannot prove these, and every one of them is core to Nomstamp:

- Camera capture — the simulator has no camera at all.
- Real GPS: the position the app trusts (ADR-004), indoors and moving.
- Apple Maps search against real Vietnamese place names and diacritics (ADR-001).
- Photo storage across many meals — files live on device, so watch app size grow.
- The art direction in sunlight, on a real display, light and dark (ADR-005).
- Vietnamese throughout, with Dynamic Type raised — long translations are where layouts break.

Do **not** ship the demo seed. `-SeedDemoData` is a launch argument, so a released build simply
never receives it; confirm `DemoSeed` cannot trigger without it before submitting.

---

## 5. Prepare the store listing

Do this while testing runs; it gates the submission, not the build.

### 5.1 Screenshots

Required: **6.9-inch iPhone** (1320×2868 or 2868×1320), up to 10. Apple scales these down for
smaller devices, so one set is enough.

The repository already produces them: `FoodMapUITests/DesignSweep.swift` captures all 13 screens,
light and dark. Run it against a 6.9-inch simulator and pick the best six or so:

```bash
xcodebuild test -project FoodMap.xcodeproj -scheme FoodMap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:FoodMapUITests/DesignSweep
```

Screenshots must show the real app. No device frames with drop shadows, no marketing slogans
pasted over the UI, no placeholder text.

### 5.2 Description, keywords, and category

- **Subtitle** — 30 characters, under the name.
- **Description** — 4000 characters. Lead with what the README leads with: a private map of the
  food you have eaten, no account, no server, photos never leave the device.
- **Keywords** — 100 characters, comma-separated, no spaces after commas, no repeating words from
  the name.
- **Category** — *Food & Drink*, secondary *Travel*.
- **Support URL** — required, and must resolve. A GitHub repository page or a one-page site is
  fine.
- **Privacy Policy URL** — required for every app, including ones that collect nothing. Say so
  plainly: the app stores everything on the device, transmits nothing, and has no analytics.

Both localisations need all of this.

### 5.3 App Privacy

*App Privacy* → *Get Started*. Nomstamp has a genuinely easy answer:

> **Do you or your third-party partners collect data from this app?** → **No**

Photos, location, and place names never leave the device and are not collected. Answering *No*
gives the app a "Data Not Collected" privacy label, which is worth advertising in the description.

Being asked for camera, photo, and location **permission** is not data collection — collection
means transmitting off the device. A wrong *Yes* here is far worse than a right *No*.

A `PrivacyInfo.xcprivacy` manifest is required only when you use certain APIs (file timestamps,
disk space, user defaults, boot time) or ship third-party SDKs. Nomstamp ships no third-party SDKs,
but if a Release archive is rejected for a missing manifest, add
`FoodMap/Resources/PrivacyInfo.xcprivacy` declaring the required-reason APIs the error names.

### 5.4 Export compliance

Asked on every upload unless you set it once in `Info.plist`, which §0.1 does:
`ITSAppUsesNonExemptEncryption = NO`. Nomstamp has no networking beyond Apple's own map and search
services, and no custom cryptography, so this is correct.

### 5.5 Age rating

Answer the questionnaire honestly; with no user-generated content shared between users, no web
view, and no gambling, Nomstamp lands at 4+.

---

## 6. Submit for review

*Distribution* → pick the build from *Build* → *Add for Review* → *Submit*.

Fill in:

- **Sign-in required?** No — there is no account.
- **Notes for the reviewer.** Say that all data is local, that granting camera, photo, and
  location permissions is needed to see the app work, and that place search uses Apple Maps.
  Reviewers testing outside Vietnam should still get results; mention a Vietnamese city they can
  search if the app looks empty otherwise.
- **Release options.** *Manually release this version* is the safe default for a first release —
  the app goes live when you press the button, not the moment review passes.

Review typically takes 24–48 hours. Rejections arrive in *App Review* with a message you can reply
to; most first-time rejections are metadata (a broken support URL, a screenshot showing something
the app does not do), not code.

---

## 7. Release, then the next version

Once approved, press *Release this version*. The app appears on the store within a few hours.

For each subsequent release:

1. Branch off `main`, do the work under the usual `docs → test cases → test code → implementation`
   order, merge.
2. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`; `xcodegen generate`.
3. Run all four suites green — the three `swift test` packages and `xcodebuild test`.
4. Tag the commit: `git tag v1.1.0 && git push --tags`. An uploaded build should always be
   traceable to a commit.
5. Archive, upload, test in TestFlight, then in App Store Connect → **+** beside *iOS App* to
   create the new version, write *What's New*, attach the build, submit.

---

## 8. Pre-flight checklist

Run through this before every upload.

- [ ] `xcodegen generate` run after the last `project.yml` change
- [ ] `CURRENT_PROJECT_VERSION` increased since the previous upload
- [ ] All four suites green
- [ ] Archived against *Any iOS Device*, Release configuration
- [ ] App icon present, 1024×1024, no alpha
- [ ] Demo seed unreachable without `-SeedDemoData`
- [ ] Both localisations complete for any new user-facing string
- [ ] Tested on a real iPhone: camera, GPS, Apple Maps search, Vietnamese, Dynamic Type

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| *Archive* greyed out | Simulator destination selected — choose *Any iOS Device (arm64)* |
| `No signing certificate "iOS Distribution" found` | Xcode → Settings → Accounts → Manage Certificates → + → Apple Distribution |
| `No Accounts: Add a new account in Accounts settings` | Nothing authenticated the build to Apple — §1 item 3. Check `AuthKey_<ASC_KEY_ID>.p8` exists and the key has the App Manager role |
| `No profiles for 'com.longnv.foodmap.app' were found` | Same cause, reported second. Fixing the account error fixes both |
| Archive fails with `ASC_TEAM_ID is still the example value` | `.env` still holds `ABCDE12345`; put your real Team ID there |
| `CODE_SIGNING_ALLOWED=NO` errors on archive | §0.1 — the flag is still applying to Release |
| Signing settings revert | You edited the generated `.xcodeproj`; put them in `project.yml` |
| Build never leaves *Processing* | Read the account holder's email — Apple explains invalid binaries there only |
| `The bundle version must be higher than…` | Bump `CURRENT_PROJECT_VERSION` |
| `Invalid Bundle. Unsupported architectures` | Archived for the simulator, or a stale `build/` — delete it and re-archive |
| TestFlight build shows "Expired" | 90 days elapsed; upload a new build |
