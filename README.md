# <img src="assets/icon-180.png" alt="" width="40"> WallConnectorLog

![iOS 18+](https://img.shields.io/badge/iOS-18%2B-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-F05138?logo=swift&logoColor=white)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A native iPhone companion to your own
[WallConnectorLog](https://github.com/mews-se/wallconnectorlog) server — live charger status,
real charge sessions and lifetime counters for the Tesla Wall Connector Gen 3, in an interface
built for the phone.

The server does the around-the-clock logging; the app is a phone-sized window into it. It talks
only to a server you run yourself. It never connects to Tesla, there is no account to create, and
nothing leaves your network.

WallConnectorLog is a sibling of [EVLog](https://github.com/mews-se/evlog-ios), the same
developer's TeslaMate companion — one app for the car, one for the charger, built the same way:
your own server, no accounts, no cloud.

[Download it on the App Store](https://apps.apple.com/app/wallconnectorlog/id6807546205) — free,
iOS 18 or later. Every version that reaches the App Store gets a
[tag and a release](https://github.com/mews-se/wallconnectorlog-ios/releases) here. `main` holds
the build most recently sent to Apple — normally the one in the store, marked by the latest tag —
while new work gathers on `dev`. To build what is in the store, start from the latest tag; for
how, see [Building](#building).

[Privacy policy](https://mews-se.github.io/wallconnectorlog-site/privacy/) ·
[Support](https://mews-se.github.io/wallconnectorlog-site/support/)

## What it does

**Overview** — the grid, the charger and the car in one picture that lights up green where energy
is moving, with the state the charger reports, power while charging, the phases carrying current
and the running session. Tiles for phase currents and voltages, handle and electronics
temperatures, the charger's Wi-Fi signal and the grid; a power chart over the last day, week or
month with a grid quality card beneath it; and the lifetime counters, with a comparison of the
charger's own energy counter against what the server logged, month by month. The Wi-Fi tile opens
the signal history.

**Sessions** — the real charge sessions the server has derived, month by month with each month's
total, each with energy, time plugged in, charging time, idle time, peak power, peak handle
temperature and average grid voltage, and power, temperature and phase-current curves. The list
exports as CSV through the share sheet. This is the part a phone app cannot do on its own: the
charger keeps no history, so an app that only samples while it is open can never show a truthful
list. The server can, and does.

**Statistics** — totals for the week, month, year or all time, energy per day for the last 30 days
and per month for the last year, and the records: largest session, longest charge, highest power,
average charging power and the idle share. With a price per kWh in Settings, cost sits next to
every energy figure.

**Settings** — the server address, on your own network or behind an HTTPS name; an optional
Grafana address, followed automatically when Grafana runs next to the server; the price per kWh;
and diagnostics: the age of the last reading, the server's clock against the phone's and the last
poll error.

**Demo mode** — with no server configured the app starts with a hint: type `demo` in the server
field and every screen runs on built-in example data, so all of the above can be tried before
anything is set up.

## What you need

- A running [WallConnectorLog](https://github.com/mews-se/wallconnectorlog) server — two files,
  `docker-compose.yml` and `.env`, are the whole install; the README over there walks through it
- The server reachable from your phone, by default on port `4680`; server 1.2 or later for the
  per-session curves, the Wi-Fi history and the counter comparison — everything else works with
  any version

The server address is the only thing the app asks for. Until one is in place the demo is a typed
word away.

The app allows plain HTTP to your own network: private addresses such as 192.168.x.x and 10.x.x.x,
`.local` names, and hostnames without a dot. That covers a LAN and a VPN alike.

A public name behind a reverse proxy with a real certificate works as well: type it without a
scheme and the app uses HTTPS on the standard port. A typed `http://` or `https://` is kept, with
that scheme's default port unless you give one.

## Building

The Xcode project is generated rather than committed, so a fresh clone has no `.xcodeproj` until
you run:

```
brew install xcodegen
xcodegen generate
```

iOS 18 or later, iPhone only.

That is enough to build and run it in the simulator. To put it on your own iPhone, change
`DEVELOPMENT_TEAM` in `project.yml` first — the identifier in the file is mine, and Xcode will not
sign for a team you are not a member of. A free Apple ID works: pick Personal Team when Xcode asks.
Apps signed that way stop launching after seven days and have to be run from Xcode again to renew.

## Licence

MIT — see [LICENSE](LICENSE).

## Disclaimer

This project is an unofficial community tool and is not affiliated with, endorsed by, or supported
by Tesla, Inc.
