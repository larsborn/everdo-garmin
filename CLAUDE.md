# Everdo Capture — working notes

Connect IQ watch app. Type a note on the watch, it reaches the Everdo inbox
whenever the user's machine is awake.

General Connect IQ knowledge lives in the user-scoped `garmin-connect-iq`
skill — the silent install failure, Storage vs Properties, background
limits, simulator traps, store submission. **Read that first.** This file is
only what is specific to this project.

## Build

```sh
./build.sh                # venux1
./build.sh venux1 run     # build + simulator
./buildall.sh             # all 62 products — must be 62/62, zero warnings
./package.sh              # bin/Everdo.iq for the store
```

`buildall.sh` is not optional before anything ships. Devices differ at
compile time: six CIQ 5.0.0 devices once rejected a `WatchUi` call inside a
`(:background)` class that every newer device accepted.

## Invariants — breaking these has consequences you cannot undo

**appID `4d358e3d5adc6de2720b297381d8b61b` is final.** It is the published
app. Change it and every user silently starts over with an empty install
and no settings. Updates go to the same listing via "Upload New Version".

**The signing key never changes.** `../keys/developer_key.der`, backed up at
`D:\Sync\Nextcloud\Keys\GarminKeys\`. The store verifies it on every update
and there is no recovery path.

**Only a confirmed 2xx dequeues** (`Flusher.onResponse`). `POST /api/items`
has no idempotency key, so retrying an ambiguous response duplicates the
item in someone's inbox. Do not "simplify" this into retrying on anything
that is not an outright failure.

**`Application.Storage` is authoritative for config, not Properties.** The
phone re-pushes its cached Properties over anything the watch writes.
Properties is an inbox, read on first run and on `onSettingsChanged` only.
Two separate bugs came from getting this wrong; `Config.mc` has the story.

## Shape of the code

| File | Role |
| --- | --- |
| `Outbox.mc` | Storage-backed queue, `(:background)`-safe |
| `Flusher.mc` | chained drain, single-flight, 2xx-only dequeue |
| `FlushService.mc` | temporal event, 30 min, runs with the app closed |
| `Api.mc` / `Config.mc` | the one place that knows where Everdo is |
| `Errors.mc` | response code -> something a user can act on |
| `EverdoView/Delegate` | main screen, capture, navigation |
| `MainMenu/SettingsMenu/QueueMenu` | menus |

`(:background)` files must not reference `WatchUi`. Where `AppBase` has to,
split it into a method annotated `(:typecheck(disableBackgroundCheck))`.

## Things that look like bugs and are not

- `languages: {"valyrian": ...}` in `bin/Everdo-settings.json` is Garmin's
  untranslated-default bucket. Normal.
- A 502 from the Everdo host means the user's machine is asleep. That is the
  expected state, not a fault — the queue exists for it.
- A ~3 s delay on a bad API key is Everdo's brute-force protection. It once
  made latency look 40x worse than it is. Measure against a 2xx.

## Constraints worth remembering before promising a feature

Everdo's HTTP API is **create-only**: `POST /api/items`, title and note,
nothing else. No project, tag, due date, and no way to read anything back.
Checklists (phase 2 in `plan.md`) therefore need a helper service reading
Everdo's SQLite file — there is no API route to that data.

## Documents

- `plan.md` — design, measured numbers, and what was wrong before it was right
- `SETUP.md` — the HTTPS requirement, which is the real barrier to entry
- `RELEASE.md` — store submission, appID history, listing text
- `store/` — listing assets and `capture.py`
