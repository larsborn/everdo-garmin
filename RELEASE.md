# Releasing to the Connect IQ Store

## Device coverage — done

62 devices, selected mechanically from the SDK's own device profiles rather
than by eye. The criteria, all three required:

- **touchscreen** (`simulator.json` -> `display.isTouch`)
- **`TextPicker` present in that device's API surface**
  (`<device>.api.debug.xml`) - without a keyboard, capture has nothing to
  type into and the app has little reason to exist on that device
- **Connect IQ >= 5.0**

Edge computers, eTrex and GPSMAP are excluded. They passed the filter, but
they are not watches and wrist capture is not their use case.

**All 62 build clean at `-l 3` with zero warnings.** `/tmp/buildall.sh` in
the history does this in a loop; rerun it after any change that touches
resources or background annotations. Building for one device proves very
little - the six CIQ 5.0.0 devices failed on a `WatchUi` call inside an
`(:background)` class that every newer device accepted.

Launcher icons are generated per declared size (40, 54, 56, 60, 61, 65, 70
px) into `resources-icon<W>x<H>/`, and `monkey.jungle` points each device at
the one it asks for. No rescaling, hence no warnings.

## minSdkVersion stays at 3.2.0 — deliberately

Lower than the APIs in use, and that is the point. A `minSdkVersion` above
the device's *actual* firmware makes the watch accept the `.prg` and then
silently never list it: no error, nothing in `CIQ_LOG.YML`, no way for a
user to report it as anything but "it did not install".

The SDK's claimed minimum per part number is not reliable here. The
development Venu X1 reports Connect IQ **6.0.2** while its SDK profile
claims the part number requires **6.0.3** - the SDK overstates. Raising
`minSdkVersion` to match the lowest target (5.0.0) would be more honest and
would buy nothing, since the explicit product list already controls who is
offered the app. It would also risk that silent failure on any device
whose real firmware trails its profile.

## Memory — not a constraint

~106 KB per device build (101-110 KB across the 62) against a **768 KB**
`watchApp` budget on every target. The 64 KB background budget is the only
tight one, and the `(:background)` build contains no UI: Outbox, Flusher,
Api, Config and Errors reference `WatchUi` nowhere. Nothing to reduce.

## Checklist

- [x] Device list decided; 62 products in `manifest.xml`
- [x] Per-device launcher icons, 7 sizes
- [x] `minSdkVersion` reviewed and deliberately left at 3.2.0
- [x] All 62 devices build clean at `-l 3`, zero warnings
- [ ] Fresh-install test: wipe app settings, confirm "Setup needed" appears
      and both editors (watch and phone) configure it
- [ ] Offline test: capture with the Everdo box asleep, confirm it queues and
      goes out later unattended
- [ ] Bad-key test: confirm "check API key" rather than a silent failure
- [x] Screenshots: store/01..06, 448x486, cropped to the screen
- [x] Store listing text (below)
- [x] Developer key backed up off-machine and hash-verified
- Public contact: `garmin-development@wallenborn.net` - shown publicly
      on the listing, deliberately not a personal address

## Beta first, and the appID it costs

The upload form warns that a Beta app is downloadable only by you, and that
publishing afterwards requires **a different appID in manifest.xml**.

Pay it. Nobody has installed this, there are no reviews or install counts
attached, and the appID is a UUID. What Beta buys is the only test
sideloading cannot give: whether a STORE-installed app gets a working
settings page in the Connect IQ phone app. The whole Storage-vs-Properties
design assumes it does, and that has never been observed - sideloaded apps
do not reliably appear there at all.

To publish after the beta:

1. `openssl rand -hex 16` for a new id (lowercase, matching house style)
2. Update **both** `manifest.xml` (`id=`) and `.appid`
3. `./buildall.sh` then `./package.sh`
4. Upload the new .iq without the Beta box ticked

Consequence worth expecting: to a watch this is a different app, so its
settings and queue start empty. Fine for a v1; it would not be fine for an
update, which must keep the same appID or every user is silently reset.

appID history - keep this straight, it is the one thing that cannot be
undone:

| appID | Used for |
| --- | --- |
| `4ff5794372e4b497de2180ec12e582f2` | sideload during development, and beta 1 |
| `1eb0645359c890ab0dcc0c49a8a2f5e0` | beta 2 - clean room, never sideloaded |
| `4d358e3d5adc6de2720b297381d8b61b` | **public release 1.0.0 — FINAL, never change this** |

Beta 2 exists because beta 1 shared its appID with the sideloaded builds.
The Connect IQ phone app caches metadata per appID, so the two installs
became indistinguishable - the app list showed one name and the detail
page a name from three builds earlier - and the settings-page question
could not be answered. Never sideload and store-install the same appID.

## "Signature check failed" on upload

Seen on the 1.0.0 beta upload, alongside `Status: Verified` and a correct
compatible-device list.

What it is NOT:
- the key is **4096-bit RSA**, so it is not the classic too-short-key cause
- it is a first upload, so "all versions must be signed with the same key
  pair" cannot apply in the usual sense

There is a Garmin-acknowledged store-checker bug that emits exactly this
message, reported Feb 2023, still open. Several developers describe it as
"a confusing warning, everything works fine". The claimed trigger is the
integer -507453934 appearing in the app - but that is 0xE1C0DE12, a PRG
section magic present in every PRG, so the diagnosis is probably
incomplete.

Decide it empirically: **if the beta installs from the store and runs, the
package is fine.** Query it with Garmin developer support before the
public release, quoting that bug.

**Update:** it did not block. The 1.0.0 beta listing published normally -
icon, description, screenshots and permissions all resolved, listed at
24 KB. So the message is advisory at upload time at worst. Still worth
raising with support before the public release, while an appID change is
still free.

## The developer key

In use:     `P:\Garmin\keys\developer_key.der`
Backed up:  `D:\Sync\Nextcloud\Keys\GarminKeys\` (verified byte-identical,
md5 `e03d0d24b1cfa0d3d25263f4e4f3058f`)

Verify the hash, not merely that a file exists - a backup of the wrong
key is worse than none, because it only surfaces when an update is
rejected, and by then there is no recovery.

There is **no recovery**. The key is what ties every future update to this
listing. Lose it and the app can never be updated; the only remedy is a new
listing, losing installs, ratings and reviews. The usual way people lose it
is a reinstall or a new machine.

The appID changes between beta and public release. The **key must not**.

## Screenshots

`store/01-ready` .. `06-setup`, each exactly 448x486 - the device's real
screen pixels, cropped out of the simulator window rather than shipped with
a bezel around them. Regenerate with `store/capture.py`.

How they were made, because it is not obvious: each state is forced at
BUILD time by a throwaway `Shot.mc` in a scratch copy of the project,
which overrides `getInitialView` and seeds Storage. Nothing is clicked.
Driving the simulator with synthetic keystrokes would type into whatever
window the user actually has focused.

Two traps when redoing this:

- **An occluded simulator window serves stale frames.** `PrintWindow` and
  even a forced `RedrawWindow` return whatever it last painted, so you
  silently capture the previous state. Keep the window visible and verify
  every image, by hash as well as by eye - two of these came out as
  byte-identical duplicates.
- **`MonkeyDoDeux` blocks once the app is actually running** (it exits
  immediately only when the push fails), so background it or the loop
  hangs forever.

## Store listing draft

**Name:** Everdo

**Short description:**
Capture to your Everdo inbox from your wrist. Works offline - notes are
saved instantly and sent when your computer is reachable.

**Description:**
Type a note on your watch and it goes straight to your Everdo inbox.

Everdo runs on your computer, which is not always awake when you have the
thought. This app saves the note on the watch immediately and delivers it
in the background whenever your machine is reachable, so nothing is lost
and you never wait for the network.

Requires Everdo desktop with its HTTP API enabled, reachable over HTTPS
with a publicly trusted certificate. Notes are created in the Everdo Inbox.

Not affiliated with the developers of Everdo.

**What to be explicit about**, because it will otherwise arrive as
one-star reviews:

- needs the Everdo *desktop* app, with the API switched on
- needs HTTPS with a real certificate; self-signed will not work, and that
  is a Connect IQ restriction rather than something this app can fix
- items land in the Inbox only - Everdo's API has no way to set a project,
  tag or due date

## Privacy and permissions

Declared: `Background`, `Communications`.

The app talks to exactly one host - the URL the user configures. No
analytics, no third-party endpoints. Worth stating plainly in the listing,
since users are handing over an API key.

**The API key travels as a query parameter**, because that is the only
authentication Everdo's API offers. It will appear in proxy and server
access logs along the path. Not something the app can avoid, but users
putting Everdo behind a shared proxy should know.

## Previously open, now done

- **Failure messages.** `Errors.mc` maps Connect IQ transport codes and HTTP
  statuses to short, actionable text: "phone not connected", "check API
  key", "check base URL", "HTTPS required", "Everdo server error". One
  honest gap remains, documented in that file: an untrusted certificate has
  no distinct code - Connect IQ reports it as a plain timeout (-300), the
  same as an unreachable host - so that message names both possibilities.
- **Queue review.** "Waiting to send" lists queued captures and deletes them
  individually, so one mistyped note no longer means discarding the lot.
