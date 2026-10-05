# Giving Everdo an HTTPS address the watch will trust

Everdo's HTTP API listens on port 11111 with a **placeholder self-signed
certificate** (`CN=example.org`). Connect IQ refuses self-signed
certificates on real hardware, so a Garmin watch cannot talk to Everdo
directly. Something trusted has to sit in front of it.

This is a Connect IQ restriction, not something this app can work around.

## What will not work

| | Why |
| --- | --- |
| `https://192.168.1.50:11111` directly | Everdo's own certificate is self-signed |
| Your own private CA | The watch's trust store does not contain it, and you cannot add to it |
| Plain `http://` | Connect IQ permits HTTP only to a small whitelist of Garmin domains |
| An IP address instead of a hostname | Certificates are issued for names |

Note the certificate check happens on whichever side makes the request. A
request relayed through the phone over Bluetooth is made by the phone, and
a watch on Wi-Fi makes it itself with a narrower trust store. Use a widely
trusted CA and both paths work.

---

## Option A — Tailscale (no domain needed)

Easiest if you do not own a domain. Tailscale issues a **real Let's Encrypt
certificate** for `<machine>.<tailnet>.ts.net`, and nothing is exposed to
the public internet.

On the machine running Everdo:

```sh
tailscale up
tailscale cert "$(tailscale status --json | jq -r .Self.DNSName | sed 's/\.$//')"
tailscale serve --bg --https=443 https+insecure://127.0.0.1:11111
```

`https+insecure` is the point: Tailscale terminates TLS with a trusted
certificate on the outside, and tolerates Everdo's bogus one on the inside
- a hop that never leaves the machine.

Install Tailscale on your **phone** as well and keep it connected; the
phone is what actually issues the request.

Base URL: `https://<machine>.<tailnet>.ts.net`

Pros: free, no domain, no port forwarding, works away from home.
Cons: Tailscale must be running on the phone.

---

## Option B — Cloudflare Tunnel

Good if you want it to work without a VPN on the phone. Needs a Cloudflare
account and a domain on Cloudflare. Nothing is port-forwarded; the tunnel
dials out.

```sh
cloudflared tunnel login
cloudflared tunnel create everdo
cloudflared tunnel route dns everdo everdo.example.com
```

`~/.cloudflared/config.yml`:

```yaml
tunnel: everdo
credentials-file: /home/you/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: everdo.example.com
    service: https://127.0.0.1:11111
    originRequest:
      noTLSVerify: true        # Everdo's own cert, local hop only
  - service: http_404
```

```sh
cloudflared tunnel run everdo
```

Base URL: `https://everdo.example.com`

**Put Cloudflare Access in front of it.** This hostname is reachable from
the whole internet, and the only thing protecting your task database is an
Everdo API key in a query string. Access with a service token turns that
into a real front door. (This app does not yet send custom headers, so
until it does, prefer Option A if that worries you.)

---

## Option C — Your own reverse proxy

For an existing homelab. Any proxy works - Caddy, nginx, Traefik - with two
requirements: a certificate from a public CA, and the upstream check
disabled because Everdo's certificate is bogus.

Because Everdo sits on a private address, use a **DNS-01** challenge; the
usual HTTP-01 needs inbound port 80, which you probably do not want.

Caddy:

```
everdo.example.com {
    tls {
        dns <your-provider> {env.PROVIDER_API_TOKEN}
    }
    reverse_proxy https://192.168.1.50:11111 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}
```

Point `everdo.example.com` at the proxy's LAN address in your internal DNS.
Add a VPN on the phone for use away from home.

---

## Verify before touching the watch

From any machine that resolves the name:

```sh
curl -v "https://everdo.example.com/time?key=YOUR_KEY"
```

You want **`200`** and a JSON body like `{"server_time_ms":...}`, with no
certificate warnings from curl. Then check the three failure signatures:

| Result | Meaning |
| --- | --- |
| curl complains about the certificate | The watch will refuse it too. Fix this first. |
| `401` after a ~3 second pause | Reached Everdo, key is wrong. The delay is Everdo's brute-force protection and is normal. |
| `502` / connection refused | Proxy is up, Everdo is not. Start Everdo, or the machine is asleep. |

That ~3 second stall on a bad key is worth remembering - it looks like a
network problem and is not.

Then on the watch: swipe up, Settings, Base URL (no trailing slash) and API
key.

## Security notes

- Everdo's API takes its key as a **query parameter**, so it appears in
  proxy and server access logs. Consider turning access logging off for
  this hostname.
- The key grants full write access to your Everdo data. Everdo's developer
  advises against exposing the API to the public internet; Option A keeps
  it off the internet entirely.
- Everdo must be **running** for delivery to succeed. That is expected -
  the watch queues captures and retries, so an asleep machine costs you
  nothing but delay.
