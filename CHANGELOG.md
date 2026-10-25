# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned
- Avatar thumbnails with a memory cap
- Photo and document downloads
- In-chat search
- Message editing, replies and forwarding
- Folders and archive
- Proxy configuration
- Local notifications through a jailbreak daemon
- Localization

## [0.2.0] - 2026-10-25

### Added
- QR code login: scan the code from an already signed-in Telegram app.
- QR encoder written from scratch in C, verified against `python-qrcode` and
  decoded with zbar (`tools/verify_qr.py`).
- "Log in by QR code" and "Log in with phone number" switches on the auth
  screen.
- Live QR refresh as TDLib rotates the login link.
- Cancelling QR login restarts the TDLib instance cleanly.

### Changed
- Two-step verification is part of the documented login path: phone or QR,
  then code, then the cloud password when the account has one.

## [0.1.0] - 2026-10-25

### Added
- Sign-in flow: phone number, login code, two-step verification, registration.
- API credentials setup screen and build-time credential injection.
- Chat list with unread badges, mentions, last message previews and connection
  status.
- Conversation view with paginated history, sender names, service messages,
  read receipts and text sending.
- Handling of edited, deleted and failed messages.
- Settings screen with account info, logout and project links.
- TDLib-based session restart after logout.
- CI pipeline producing a `.deb` and an unsigned `.ipa`, with a cached static
  TDLib build for iOS 12 arm64.

### Notes
- No media, avatars, notifications or proxy support yet.
- TDLib pinned to v1.8.0; OpenSSL 1.1.1w cross-compiled for iOS.
