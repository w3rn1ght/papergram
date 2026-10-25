# Security policy

## Supported versions

Papergram is a personal, open-source client. Only the latest release receives
fixes.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private
vulnerability reporting (Security → Report a vulnerability) or contact the
maintainer listed in the repository profile.

Include reproduction steps, affected versions and any relevant logs. Never
include your `api_hash`, phone number, login codes or session data.

## What the app stores

- **API credentials** entered in the app are kept in `NSUserDefaults`.
- **TDLib session data** (authorization key, message database) is kept in the
  app container under `Library/Application Support/Papergram`.
- **The TDLib database is not encrypted** (empty encryption key). It is
  protected by the iOS application sandbox, exactly like most jailbreak apps.
  Use a device passcode and avoid installing untrusted tweaks.

## Secrets in CI

`TG_API_ID` and `TG_API_HASH` are repository secrets. They are compiled into a
build artifact when configured; treat distributed builds accordingly. Builds
from forks never receive them.
