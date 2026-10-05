# Everdo on Garmin — capture + checklists

Plan of record. Written 2026-10-04.

Target device: **Venu X1**.

## Device facts

Read from the installed SDK, `%APPDATA%\Garmin\ConnectIQ\Devices\venux1`,
not from the web compatibility page (which lags).

| | |
| --- | --- |
| Part number | `006-B4603-00` — matches what HA reports for the watch |
| Connect IQ | **6.0.3** (listed under "API level 6.0" in SDK Manager) |
| Family | `rectangle-448x486`, AMOLED, 16 bpp, touch |
| watchApp memory | **768 KB** |
| background memory | **64 KB** |
| glance memory | **64 KB** |
| App storage | **10 MB** (`appStorageCapacity`) |
| Max .prg size | 64 MB |

Three consequences:

- **The outbox is effectively unbounded.** 10 MB of app storage against
  queue entries of a few hundred bytes. Still bound it, but generously -
  thousands of entries, not dozens.
- **64 KB of background memory is comfortable**, where older devices had
  16-32 KB. The `(:background)` build can hold real queue logic, not just a
  single request.
- **The glance OOM does not apply here.** GarminHomeAssistant's known issue
  12 is about devices with a 32 KB glance budget; this one has 64 KB.

## Goal

Two features, deliberately phased so the first ships without asking users to
run anything beyond Everdo itself.

1. **Capture** — free-text item straight into the Everdo inbox from the wrist,
   queued locally and delivered whenever the Everdo box is reachable.
2. **Checklists** — pull one list (packing, say), tick items off offline.

## Architecture

```
Venu X1  --BT-->  phone (Garmin Connect)  --HTTPS-->  Everdo  POST /api/items
            Application.Storage outbox
```

Transport is `Communications.makeWebRequest` only.

**Not** the Connect IQ companion-app channel: Garmin bug **CIQQA-4631**
(filed 2026-08-12, acknowledged, unfixed) means `Communications.transmit`
from the watch is accepted and then never delivered to the Android app.
It reproduces on Garmin's own SDK samples. Avoiding that channel is the single
most important constraint on this design.

## Hard facts established during research

| Fact | Consequence |
| --- | --- |
| Everdo's HTTP API is **create-only** (`POST /api/items`, title + note) | Checklists cannot come from the API |
| Everdo data is a plain **SQLite** db (`item`, `item_list`, `tag`, per-field `*_ts`) | Checklists can come from the file. `larsborn/everdo` already reads it |
| Everdo must be **running**; no headless mode (confirmed by its developer) | Outbox is mandatory, not a nicety |
| Connect IQ rejects **self-signed and private-CA** certs on real hardware | Everdo's stock `CN=example.org` cert can never be talked to directly |
| Garmin SDK allows plain HTTP only to a **whitelist** of domains (`garmincdn.com`) | The Pi-hole override trick exists; unsupported, not used here |
| `isFocused` reportedly a no-op | Send title + note only |

## Phase 0 — CLOSED (hardware, 2026-10-04/05)

**End to end verified.** Text entered on the watch, queued in
`Application.Storage`, delivered through Traefik to Everdo, dequeued on a
confirmed 2xx, item present in the Everdo Inbox. The architecture in this
document survived contact with hardware without a structural change.

Carried into phase 1 unchanged: the outbox, the chained flush, the
single-flight guard, and the only-a-confirmed-2xx-dequeues rule.

Ergonomic note: the first two real captures came out as "Test" and "Yest" -
T and Y are adjacent. Free text works, but typos on a 448 px keyboard are
easy, so the real app should not make free text the only path for anything
that has a small fixed vocabulary.

## Phase 0 — RESULTS (measured on hardware 2026-10-04)

**Spike 2: PASS.** `TextPicker: YES` on firmware 17.39 / CIQ 6.0.2. Free-text
capture is real; no canned-phrase fallback needed.

**Spike 3: PASS, and better than assumed.**

| | |
| --- | --- |
| Transport round trip | **151-174 ms** (200 + JSON, via phone relay) |
| Requests per 20 s background window | **~100** |
| Background service | fires with the app closed, returns in 2-16 ms when queue empty |

The ~600 ms BLE_QUEUE_FULL floor that GarminHomeAssistant documents did not
bite, because we chain requests rather than firing them in parallel - the
round trip supplies the spacing by itself. Keep chaining; watch for
`BLE_QUEUE_FULL` if that ever changes.

**Throughput is a non-issue.** Any realistic capture queue drains in a single
background window. Phase 1 can use a long interval purely to save battery,
with no throughput cost.

### The 6.15 s red herring

The first measurements showed a flat ~6150 ms per request, four samples
inside 2 ms. Cause: the spike deliberately used a WRONG api key, and
**Everdo stalls ~3.0 s on a bad key** (verified with curl from the LAN:
3.045 / 3.023 / 3.030 s) as brute-force protection. Garmin Connect Mobile
appears to retry the 401 once, roughly doubling it.

So "a wrong key costs the same round trip and writes nothing" was half
wrong, and it had the spike measuring the one path the real app never takes.
Lesson for any future latency work here: **measure against a 2xx**, not an
auth failure.

A/B probe that settled it, same Traefik and cert, one gesture:

```
A401 6312 6180 6150   POST everdo, wrong key
B200  220  151  151   GET a 200 + JSON control endpoint
meanA 6214  meanB 174
```

### Also learned

- `minSdkVersion` must be well below the device's CIQ version. Set to 6.0.0
  against a device reporting **6.0.2**, the watch accepted the .prg onto disk
  and then silently never listed it - no error, nothing in `CIQ_LOG.YML`.
  3.2.0 works. The SDK device profile claims the part number wants 6.0.3,
  so the firmware is behind the SDK; worth updating but not blocking.
- Sideloaded apps do not reliably get a settings page in the Connect IQ phone
  app. Spike values are compiled in as property defaults instead.
- **`properties.xml` values are DEFAULTS, applied only when the device has no
  stored value for that property.** Once the app has run, the value is
  persisted on the watch and survives re-sideloading of the same application
  id - a rebuild with a changed default does NOT take effect. Cost an hour:
  the spike kept posting its deliberately wrong key after the real one was
  put in, presenting as a 401 at ~6.4 s, which looks exactly like a network
  problem and is in fact Everdo's brute-force stall telling the truth.

  **Resolved** - see "Settings" below. No credential is baked into the
  build any more.

## Settings — two stores, and which one wins

Editable from both the phone and the watch, which needed a deliberate
design because the two places Connect IQ offers behave differently:

| Store | Owner | Behaviour |
| --- | --- | --- |
| `Application.Storage` | the app | never synced; a watch-side write stays written |
| `Application.Properties` | Garmin Connect Mobile | the phone re-pushes its cached copy to the watch |

**Storage is authoritative. Properties is an inbox from the phone**, read at
exactly two moments: on start for a key Storage does not have yet, and on
`onSettingsChanged`, which is a real change event. Never on an ordinary
launch. A menu item, "Use phone settings", forces an import for when the
phone is right and the watch is stale.

Two bugs were burned getting here, both worth not repeating:

1. `properties.xml` values are DEFAULTS. They apply only when the device has
   nothing stored, and they survive reinstalling the same application id, so
   shipping a new build does **not** change a stored setting.
2. A first fix re-read Properties on every start, guarded by a mirror of the
   last imported value. The guard did not hold: the mirror was updated with
   the value typed on the *watch*, so the phone's unchanged stale value then
   looked like a new phone edit and was imported over the top. The key
   reverted on every launch.

The lesson in both: a value the phone keeps re-asserting is indistinguishable
from a value the phone just changed, so do not try to tell them apart. Pick
an authoritative store and import on events only.

Verified end to end on hardware: key set on the watch, survives restart,
capture reaches the Everdo inbox.

## Phase 0 — spikes (original plan, kept for the reasoning)

**Scaffold exists**: `everdo-spike/`, a venux1-only Connect IQ app covering
spikes 2 and 3 in one build. Compiles clean at strict type-check level 3
against SDK 9.2.0. See its README for how to run it and what to record.

### Spike 1 — TLS on real hardware — **ALREADY PASSED**

No work needed. GarminHomeAssistant on this same Venu X1 is already making
successful HTTPS calls to another host behind the same proxy — same wildcard cert,
same hostname pattern, same BT relay through the phone. Toggles work and the
watch is posting telemetry back into HA. The device trusts this chain today.

What remains is not a TLS question but a plumbing one: how the watch reaches
Everdo. See "Open decision" below.

### Spike 2 — TextPicker on this firmware — mostly pre-answered

`TextPicker` and `TextPickerDelegate` are both present in the device's own API
surface (`venux1.api.debug.xml`, 13 and 24 references). That is the SDK's
per-device manifest, not the generic web list, so free-text capture is
all but certain.

What is left is firmware, which no file on disk can answer - Garmin have said
the simulator does not model firmware differences. So this drops from "find
out before designing the product" to "confirm on hardware when convenient".
Keep the `WatchUi has :TextPicker` guard regardless.

Remaining question is ergonomic rather than technical: how tolerable is
entering a task title on a 448x486 touchscreen.

### Spike 3 — background flush

Register a temporal event, confirm it fires with the app closed, confirm
`makeWebRequest` works from the `(:background)` build, and measure how many
sequential POSTs fit the 30 s window at >= 600 ms spacing. Yields the real
batch size.

## Phase 1 — capture MVP

Outbox in `Application.Storage`: `{local_id, title, note, created_ts, attempts}`.

Flow: glance → Capture → TextPicker → append to outbox → immediate flush
attempt. The item is saved the instant it is confirmed; the network is never
in the user's way.

Flush: sequential chained requests, >= 600 ms apart, stop on first failure,
retain the remainder. GarminHomeAssistant hit `Communications.BLE_QUEUE_FULL`
firing faster than this and found 600 ms sustainable on a Venu 2, 500 ms not.

Background temporal event at **30–60 min**, not the 5 min minimum — the target
is usually powered off and each failed attempt costs battery.

Settings: base URL, API key, and two free-form HTTP header name/value pairs.
Ship the headers from day one even though Phase 1 does not need them; they are
what makes the Cloudflare Access path work in Phase 3, and retrofitting
settings is worse than shipping unused ones.

**Known residual risk — duplicates.** `POST /api/items` accepts no idempotency
key, so a lost response on a successful write creates a duplicate on retry.
Retry only on network-level failure, never on an ambiguous one. Accept rare
duplicates; `larsborn/everdo` already does title dedup for a cleanup pass.

## Phase 2 — checklists

Small read-only service on the Everdo machine, built on `larsborn/everdo`
(read-only SQLite, zero dependencies, already does checklist compilation).
One endpoint: `GET /lists/<id>` → `{title, items[]}`.

Watch downloads while online, caches in Storage, ticks off entirely offline.
**Tick state stays on the watch.** Packing state is ephemeral — Everdo does not
need to know which socks are in the bag — and this removes the write-back
problem completely.

Write-back via the `*_ts` last-write-wins columns is visible in the schema and
is **explicitly out of scope**. Writing into a running app's database is
unsupported and not worth it for this payoff.

## Phase 3 — distribution

`cloudflared` on the Everdo box plus Cloudflare Access service tokens in the
two custom headers, so users need no certificate of their own. This is the
route GarminHomeAssistant added in v3.1 for exactly this problem; its own
README is blunt that it otherwise offers no support for working around the
HTTPS restriction.

Be honest in the README that the bar is a Cloudflare account and a domain.
Lower than ACME plus split-horizon DNS, but not zero. Note that the most
popular answer in this space — Nabu Casa for HA — is itself a hosted relay,
just one run centrally rather than per user.

## Open decision — how the watch reaches Everdo

Everdo serves its stock self-signed cert, which the watch will not accept.
Three ways to fix that, unresolved:

1. **Reverse-proxy route** (`everdo.example.com` already resolves to
   `.112` via the blocky wildcard — no DNS work). Needs
   `insecureSkipVerify: true` on the serversTransport, because the upstream
   cert is bogus. *Blocked:* the edit was refused by a TLS-weakening guard and
   needs explicit approval. No renewal job; Traefik owns the wildcard.
2. **Pin Everdo's cert** via `rootCAs` + `serverName: example.org` on the
   serversTransport. No TLS weakening and no private key moved — only a public
   cert copied — but adds a second single-file bind mount and breaks silently
   if Everdo ever regenerates its cert.
3. **Put the real wildcard cert into Everdo** (`cert.pem`/`key.pem` in
   `%APPDATA%\Everdo`) and point DNS at `.128` directly. Most faithful to the
   Phase 3 architecture, and no proxy at all — but moves a private key onto the
   workstation and reintroduces a 90-day copy job that will fail quietly.

## Risk register

| # | Risk | Mitigation |
| --- | --- | --- |
| 1 | ~~Real-device TLS~~ | Retired — proven by the working HA app |
| 2 | Cert renewal breaks the path | Only applies to option 3 above |
| 3 | Duplicate items on retry | Retry on network failure only; dedup pass |
| 4 | TextPicker unavailable | Largely retired - present in the device API surface. Guard anyway; confirm on hardware |
| 5 | Battery drain from polling a box that is off | 30-60 min interval; flush on app open. Now purely a battery choice - throughput measured at ~100 requests per window, so a long interval costs nothing |
| 6 | API is create-only | Accept; title + note |

## Notes

- Traefik's `dynamic.yml` is a single-file bind mount with no
  `--providers.file.watch`. A commit alone does not apply: `docker restart
  traefik`, then verify **inside** the container, not just on the host.
- The route would be LAN-only — the wildcard is NXDOMAIN on public
  DNS. Everdo's API key travels as a query parameter, and its developer warns
  against public exposure, so keep it that way.
