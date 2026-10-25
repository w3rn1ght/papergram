# Contributing

Thanks for taking the time to look at Papergram. The project is deliberately
small, and keeping it small is the main design constraint.

## Project scope

Papergram is a **text-first** Telegram client for iOS 12 devices with 1 GB of
RAM. Changes that add image decoding, animation frameworks, Swift or large
dependency trees are usually rejected — not because they are bad, but because
they defeat the point of the app.

Good pull requests:

- fix a crash, a protocol edge case, or incorrect UI state
- reduce memory use or main-thread work
- improve accessibility or localization
- add missing TDLib update handling for existing features

Please open an issue before starting a large feature.

## Development setup

Requirements:

- macOS with Xcode 15 or newer
- [Theos](https://theos.dev) (`ldid`, `dpkg`, `xz`)
- CMake and `gperf`
- a jailbroken iOS 12 device, or patience with the unsigned IPA

```sh
export THEOS=~/theos
bash scripts/build-tdlib.sh     # cached after the first run
make package FINALPACKAGE=1
```

The TDLib build is slow but stable. Do not change the pinned versions in
`scripts/build-tdlib.sh` without a reason — the cache key includes the script
hash, so every edit invalidates CI's cache.

## Performance rules

These are review blockers:

1. Never measure text in `cellForRowAtIndexPath:` or during scrolling. Use the
   cached `PGMessageLayout`.
2. Never decode images on the main thread. Papergram currently has no images.
3. No `reloadData` on every update. Data notifications must be coalesced.
4. No Auto Layout inside reusable cells.
5. No iOS 13+ APIs. The deployment target is 12.0 and the build must run on an
   iPad Air 1.

## Code style

- Objective-C, ARC, `PG` class prefix.
- Four spaces, braces on the same line as the signature.
- Prefer small, explicit methods over clever abstractions.
- Keep new files in `app/` and add them to the Xcode-less Theos build by placing
  them under `app/*.m`; no Makefile edits are needed.
- User-facing strings are currently English.

## Secrets

**Never commit `api_id` or `api_hash`.** CI reads them from repository secrets
(`TG_API_ID`, `TG_API_HASH`). The generated `app/PGSecrets.h` from a local build
must not be committed either.

If you accidentally push a key, revoke it at my.telegram.org immediately and
rewrite the branch.

## Commits and pull requests

- Keep commits focused and descriptive.
- Update `CHANGELOG.md` for user-visible changes.
- Describe how you tested the change, including the device and iOS version.
- Screenshots are welcome for UI changes.

## Reporting bugs

Use the bug report template. Include:

- device model and iOS version
- jailbreak and installation method
- Papergram version
- steps to reproduce
- a TDLib log excerpt if relevant (see below), with phone numbers and API
  hashes removed

The log lives at:

```
/var/mobile/Containers/Data/Application/<Papergram>/Library/Application Support/Papergram/tdlib.log
```

Set `PGLogVerbosity` to `1` or `2` in `Resources/Info.plist` for more detail.
