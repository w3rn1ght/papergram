<div align="center">
  <img src="Resources/AppIcon1024.png" width="120" alt="Papergram icon">

  <h1>Papergram</h1>

  <p>A lightweight, TDLib-powered Telegram client for iOS 12 and older iPads.</p>

  <p>
    <a href="https://github.com/w3rn1ght/papergram/actions/workflows/build.yml"><img alt="Build" src="https://github.com/w3rn1ght/papergram/actions/workflows/build.yml/badge.svg"></a>
    <a href="https://github.com/w3rn1ght/papergram/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/w3rn1ght/papergram?display_name=tag"></a>
    <img alt="Platform" src="https://img.shields.io/badge/iOS-12.0%2B-2F6FED">
    <img alt="Architecture" src="https://img.shields.io/badge/arch-arm64-informational">
    <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  </p>

  <p><b>Built for the iPad Air 1.</b> A7 · 1 GB RAM · iOS 12.5.7</p>
</div>

---

## Why another client?

The official Telegram app no longer supports iOS 12, and the last compatible
builds are heavy for a 1 GB device: image-heavy chat lists, asset catalogs,
animated everything. Papergram takes the opposite approach:

- **TDLib does the protocol work.** No reimplementation of MTProto, sessions,
  updates, or reconnection logic.
- **Text-first UI.** No avatars, no media thumbnails, no stickers. Every visible
  pixel is drawn with UIKit primitives, so scrolling stays smooth on an A7.
- **Small memory budget.** Message paging, per-width layout caching, coalesced
  table reloads and a 400-message in-memory cap.
- **Jailbreak-friendly.** Ships as a plain `.deb` that installs into
  `/Applications`, with an unsigned `.ipa` for sideloading.

## Features

| | |
|---|---|
| **Sign in** | Phone number, login code, two-step verification, QR code login, account registration |
| **Chat list** | Unread badges, mentions, last message previews, connection status |
| **Conversations** | Paginated history, sender names in groups, service messages |
| **Messaging** | Send and receive text, delivery failures, edited and deleted messages |
| **Session** | Read receipts, open/close chat events, log out and sign in again |
| **Settings** | Account info, version, source and issue links |

Everything is plain Objective-C and UIKit. No Swift runtime, no third-party UI
frameworks, no asset catalogs, no storyboards.

## Not included (yet)

Papergram is intentionally narrow. The current release does **not** support:

- media download or inline previews (photos, videos, voice, documents)
- avatars and profile photos
- stickers, GIFs, reactions
- message search, folders, archives
- drafts, editing, forwarding, replies
- push notifications while the app is closed
- secret chats, calls, voice chats
- proxy / MTProxy configuration (supported by TDLib, not exposed in the UI)

See the [roadmap](#roadmap) for what comes next.

## Install

### Jailbroken device (recommended)

Papergram targets rootful jailbreaks on iOS 12 (unc0ver, checkra1n, Chimera).
The package is `iphoneos-arm` and installs to `/Applications`.

1. Download `Papergram-*.deb` from [Releases](../../releases).
2. Open it in **Filza** and tap *Install*, or install from a shell:

   ```sh
   dpkg -i Papergram-0.2.0.deb
   ```

3. If the icon does not appear immediately:

   ```sh
   uicache -p /Applications/Papergram.app
   ```

4. Launch Papergram and follow the setup screen.

### Unsigned IPA

Every CI run also produces `Papergram-unsigned.ipa`. It is not signed, so use
AltStore, Sideloadly or a developer certificate. Free provisioning profiles
expire after 7 days; a jailbroken device does not need one at all.

### API credentials

Telegram requires every third-party client to use its own `api_id` and
`api_hash`. Papergram never ships someone else's keys.

1. Sign in at [my.telegram.org](https://my.telegram.org).
2. Open **API development tools** and create an application.
3. Either:
   - paste the credentials into the app's first-run setup screen, or
   - build with the `TG_API_ID` / `TG_API_HASH` secrets so they are compiled in.

The in-app setup stores the values in `NSUserDefaults`, which is enough for a
personal build. Do not commit them, and do not publish builds that contain
someone else's keys.

## Build from source

### Requirements

- macOS with Xcode 15 (or newer) and the iOS SDK
- [Theos](https://theos.dev) with `ldid`, `dpkg` and `xz`
- CMake, `gperf`, Python 3
- About 4 GB of free disk space for the TDLib build

```sh
brew install cmake gperf ldid dpkg xz

git clone --recursive https://github.com/theos/theos.git ~/theos
export THEOS=~/theos
```

### Build

```sh
git clone https://github.com/w3rn1ght/papergram.git
cd papergram

# Static TDLib for iOS arm64. Takes 20-60 minutes the first time.
bash scripts/build-tdlib.sh

# Optional: compile in your API credentials.
TG_API_ID=123456 TG_API_HASH=0123456789abcdef0123456789abcdef \
  python3 scripts/make_secrets.py

make package FINALPACKAGE=1
```

The package appears in `packages/`, the staged app bundle in
`.theos/_/Applications/Papergram.app`.

To build an unsigned IPA:

```sh
mkdir -p build/Payload
cp -R .theos/_/Applications/Papergram.app build/Payload/
(cd build && zip -qry Papergram-unsigned.ipa Payload)
```

### Verification

The QR encoder is checked against `python-qrcode` and decoded with zbar:

```sh
pip install qrcode pillow pyzbar
python3 tools/verify_qr.py
```

It needs a C compiler and the zbar shared library (`apt install libzbar0`,
`pacman -S zbar`). The script is not part of the application build.

### CI

`.github/workflows/build.yml` builds everything on `macos-14`:

1. restores or builds a static TDLib (cached by script hash),
2. injects `TG_API_ID` / `TG_API_HASH` from repository secrets when present,
3. builds the `.deb` with Theos,
4. verifies that the binary is arm64 and the bundle is complete,
5. uploads the artifacts, and on `v*` tags publishes a GitHub release.

Because the TDLib archive rarely changes, most runs complete in a couple of
minutes.

## Architecture

```
┌────────────────────────────── Papergram.app ──────────────────────────────┐
│  UIKit (Objective-C)                                                      │
│  ┌────────────┐   ┌──────────────┐   ┌────────────────┐   ┌────────────┐  │
│  │    Auth    │   │  Chat list   │   │  Conversation  │   │  Settings  │  │
│  └─────┬──────┘   └──────┬───────┘   └───────┬────────┘   └─────┬──────┘  │
│        └───────────────┬─┴───────────────────┴──────────────────┘         │
│                 ┌──────▼───────┐                                          │
│                 │   PGClient   │  JSON + @extra, one receive thread       │
│                 └──────┬───────┘                                          │
└────────────────────────┼──────────────────────────────────────────────────┘
                         │ tdjson C API
                 ┌───────▼────────┐
                 │  TDLib 1.8.0   │  static · arm64 · iOS 12 deployment
                 └───────┬────────┘
                         │ MTProto
                    Telegram data centers
```

More detail in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Performance notes

The iPad Air 1 is the design constraint, not an afterthought.

| Decision | Why |
|---|---|
| Text-only chat list | No image decoding or cache on the main thread |
| Vector send button and logo | No PNG decoding at launch |
| Row heights cached per width | No text measurement while scrolling |
| Chat list reloads coalesced at 200 ms | Update bursts do not thrash the table |
| 40-message pages, 400-message cap | Predictable memory use |
| `use_file_database = false` | No media cache, fewer writes |
| No Swift runtime | Smaller binary, faster launch |

Release footprint: **4.9 MB `.deb`**, **~20 MB installed**, **7.4 MB unsigned
`.ipa`**.

Typical resident memory after opening a few chats: **under ~150 MB**, with no
image cache to grow over time.

## Roadmap

- [ ] Avatar thumbnails with a strict memory cap
- [ ] Photo and document download with manual size limits
- [ ] Message search inside a chat
- [ ] Message editing, replies and forwarding
- [ ] Folders and archive
- [ ] MTProxy / SOCKS5 configuration
- [ ] Local notifications via a jailbreak daemon
- [ ] Russian and other localizations

## Limitations

- **No push notifications.** Without an APNs relay the app cannot be woken in
  the background. Messages arrive while Papergram is running or on next launch.
- **No media.** Attachments are rendered as a placeholder label.
- **TDLib 1.8.0.** Pinned for reliable iOS 12 builds. It is an older API layer,
  but authentication, chats and messages work as expected.
- **Jailbreak only for the `.deb`.** The unsigned IPA requires sideloading.

## Contributing

Bug reports and pull requests are welcome. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) first — especially the rule about API keys.

## License and disclaimer

Papergram is released under the [MIT License](LICENSE).

It is an independent project. It is **not** affiliated with, endorsed by, or
connected to Telegram Messenger LLP. Telegram is a trademark of Telegram
Messenger LLP. Use it at your own risk and follow the
[Telegram API Terms of Service](https://core.telegram.org/api/terms).
