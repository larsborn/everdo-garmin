# Everdo for Garmin

Capture to your [Everdo](https://everdo.net) inbox from the wrist.

Type a note on the watch and it is saved immediately, then delivered to
Everdo's HTTP API whenever that machine is reachable. Everdo runs as a
desktop app, so it is often asleep when you have the thought - the watch
queues locally and sends later rather than losing it.

## Requirements

- **Everdo desktop** with the HTTP API enabled: *Settings > API*.
- **HTTPS with a publicly trusted certificate.** Connect IQ rejects
  self-signed certificates on real hardware, and Everdo ships a placeholder
  one, so Everdo cannot be addressed directly. **See [SETUP.md](SETUP.md)**
  for three ways to do this, including one that needs no domain of your own.
  Plain HTTP will not work either.
- A phone in Bluetooth range running Garmin Connect; that is what carries
  the request.

## Setup

On the watch: swipe up, **Settings**, then set

| | |
| --- | --- |
| Base URL | `https://everdo.example.com` (no trailing slash) |
| API key | from Everdo, *Settings > API* |

Or set the same two values in the Connect IQ phone app. Both editors write
the same configuration - see `source/Config.mc` for how that is reconciled,
which is less obvious than it sounds.

## Using it

- **Tap** - type a note. It is saved the moment you confirm, and sending
  happens in the background. You never wait for the network.
- **Swipe up** - Send now, Settings, Discard queue.
- Anything undelivered is retried automatically, roughly every 30 minutes
  and whenever you open the app.

Captures always land in the Everdo **Inbox**. That is a limit of Everdo's
API, which accepts only a title and note - there is no way to set a
project, list, tag or due date when creating an item.

## Building

```sh
./build.sh                # venux1
./build.sh venux1 run     # build, then launch the simulator
```

Resolves the active SDK from `current-sdk.cfg`, signs with
`../keys/developer_key.der`, and builds with `-w -l 3` - warnings on, strict
type checking. It passes clean; keep it that way.

## Notes

`plan.md` carries the design and, more usefully, the things that were wrong
before they were right - the silent install failure from an over-high
`minSdkVersion`, the latency measurement that was really measuring an
anti-brute-force delay, and why device Storage rather than Connect IQ
Properties is the authoritative configuration store.
