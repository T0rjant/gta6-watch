# GTA VI Watch 🌴 — GTA 6 & Take-Two (TTWO) tracker for macOS

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black) ![Chip](https://img.shields.io/badge/Apple%20Silicon-native-orange) ![Swift](https://img.shields.io/badge/Swift-6-F05138) ![Size](https://img.shields.io/badge/size-~1.3%20MB-ff2e83) ![License](https://img.shields.io/badge/license-MIT-7b2ff7)

**The all-in-one GTA 6 dashboard for your Mac.** A native macOS menu bar app that tracks everything around **Grand Theft Auto VI** and **Take-Two Interactive (NASDAQ: TTWO)**: live stock price, official Rockstar Games & Take-Two announcements, gaming & finance press coverage, native alerts, and a countdown to the GTA VI release date.

Built with SwiftUI. **Zero dependencies, no API keys, ~1.3 MB, sandboxed.** French 🇫🇷 / English 🇺🇸 interface. Made by **Torjant**.

> 🇫🇷 **Version française plus bas** — [cliquer ici](#-version-française)

<!-- SCREENSHOT: décommente la ligne suivante après avoir ajouté docs/screenshot.png
![GTA VI Watch dashboard](docs/screenshot.png)
-->

## Features

- 📊 **Live TTWO stock** — price, day change, intraday chart, volume, 52-week range, next earnings date, **USD or EUR** (real-time exchange rate)
- 🖥️ **Menu bar ticker** — TTWO price always visible next to your clock; click for a quick summary popover
- 📢 **Official communication** — Take-Two Investor Relations press releases + Rockstar Games Newswire
- 📰 **Press & marketing coverage** — gaming and finance articles, auto-tagged (🎬 Trailer, 💹 Finance, 📣 Marketing, 📅 Release)
- 🔔 **Native macOS alerts** — official announcements, stock moves beyond your threshold (1–10 %), new articles
- 🌴 **GTA VI release countdown** — days left until launch, editable if Rockstar shifts the date
- 🌍 **Bilingual** — switch French/English: UI *and* news sources follow
- 🚀 **Launch at login**, closes to the menu bar, ~0 % CPU when idle

## Install

**Requirements**: Apple Silicon Mac (M1 or newer), macOS 14+.

1. Download the `.pkg` from the latest [Release](../../releases)
2. Double-click it — the app installs into `/Applications`
3. First launch: macOS will warn because the app is not notarized (no 99 €/year Apple Developer account). Go to **System Settings → Privacy & Security → "Open Anyway"**. Once.

Prefer zero warnings? **Build it yourself in 30 seconds** (see below) — same result, compiled on your machine.

## Build from source

```bash
git clone https://github.com/Torjant/gta6-watch.git && cd gta6-watch
./build.sh
```

Only needs Apple's Command Line Tools (`xcode-select --install`) — no Xcode. The script outputs both the `.app` and the `.pkg` in `build/`.

## Data sources

| Data | Source | Default refresh |
|---|---|---|
| TTWO stock & EUR/USD | Yahoo Finance (~15 min delayed) | 5 min (1 h when NASDAQ is closed) |
| Official news | Take-Two IR RSS + BusinessWire + Rockstar (Google News) | 30 min |
| Press | Google News (GTA 6 / Take-Two / Rockstar query) | 30 min |

No API keys, no account, no server.

## Security & privacy

- **App Sandbox** — outbound network connections only; no access to your files, mic, or camera; nothing listens for incoming connections
- **Hardened Runtime** + strict **App Transport Security** (HTTPS only)
- **Link filtering** — only `http(s)` links from feeds can open, in your default browser
- **Zero data collected** — no telemetry, no analytics, no account; the only traffic is read-only requests to the three public sources above

## Code architecture

```
Sources/
├── App.swift       — entry point, scenes (window + menu bar)
├── Models.swift    — domain types + Yahoo Finance decoding
├── L10n.swift      — FR/EN strings + localized formatting
├── Fetchers.swift  — networking (Yahoo, RSS) + dependency-free RSS parser
├── Store.swift     — observable state, timers, alert logic
├── Notifier.swift  — macOS notifications
└── Views.swift     — SwiftUI (dashboard, popover, settings)
```

---

# 🇫🇷 Version française

**Le dashboard GTA 6 tout-en-un pour Mac.** App native (SwiftUI) de veille **Grand Theft Auto VI** et **Take-Two Interactive (NASDAQ : TTWO)** : bourse en direct, annonces officielles Rockstar / Take-Two, presse gaming & finance, alertes natives, compte à rebours de la sortie.

## Fonctionnalités

- 📊 **Bourse TTWO en direct** — cours, variation, graphique intraday, volume, 52 semaines, prochains résultats, **USD ou EUR** (taux de change en temps réel)
- 🖥️ **Ticker barre de menus** — le cours TTWO toujours visible à côté de l'heure ; un clic ouvre le résumé
- 📢 **Communication officielle** — communiqués Take-Two IR + Rockstar Newswire
- 📰 **Presse & marketing** — articles auto-étiquetés (🎬 Trailer, 💹 Finance, 📣 Marketing, 📅 Sortie)
- 🔔 **Alertes macOS natives** — annonces officielles, mouvement de bourse au-delà de ton seuil (1–10 %), nouveaux articles
- 🌴 **Compte à rebours GTA VI** — date modifiable si Rockstar re-décale
- 🌍 **Bilingue** — le français/anglais bascule l'interface **et** les sources d'actus
- 🚀 **Lancement au démarrage**, vit dans la barre de menus, ~0 % CPU au repos

## Installation

**Prérequis** : Mac Apple Silicon (M1+), macOS 14+.

Télécharge le `.pkg` de la dernière [Release](../../releases), double-clique. Au premier lancement, macOS bloque (app non notarisée — pas de compte développeur Apple à 99 €/an) : **Réglages Système → Confidentialité et sécurité → « Ouvrir quand même »**. Une seule fois.

Alternative sans avertissement : compiler soi-même (30 secondes, section *Build from source* ci-dessus).

## Sécurité

App Sandbox (réseau sortant uniquement), Hardened Runtime, HTTPS strict, filtre de liens, **zéro donnée collectée** — pas de télémétrie, pas de compte, pas de serveur.

---

## License / Licence

[MIT](LICENSE) — © 2026 **Torjant**
