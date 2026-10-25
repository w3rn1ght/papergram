# Architecture

Papergram is a thin UIKit layer over TDLib's JSON interface. The goal is to
keep the protocol work in a battle-tested library and spend the app's
complexity budget on doing as little as possible.

## Layers

```
UI (UILabel / UITableView / UIView)
        │ notifications + delegate (main thread)
PGClient (Objective-C, ~800 lines)
        │ td_json_client_send / td_json_client_receive
TDLib (static, C++)
        │ MTProto over TCP
Telegram
```

### PGClient

`PGClient` owns exactly one TDLib instance.

- **Sending.** Requests are plain `NSDictionary` objects serialized with
  `NSJSONSerialization`. A monotonically increasing `@extra` string is attached
  when a completion block is needed.
- **Receiving.** One dedicated `NSThread` calls `td_json_client_receive` in a
  loop with a 0.5 s timeout. Every object is parsed and handed to the main
  queue, preserving order.
- **Auth.** TDLib's `updateAuthorizationState` is mapped to a small enum.
  `PGAuthStateNeedsCredentials` is a local pseudo-state used when no API keys
  are configured. Login can go two ways:
  - **Phone.** `setAuthenticationPhoneNumber` → `checkAuthenticationCode` →
    `checkAuthenticationPassword` when the account has two-step verification.
  - **QR.** `requestQrCodeAuthentication` moves TDLib into
    `authorizationStateWaitOtherDeviceConfirmation`. TDLib rotates the
    `tg://login?token=…` link; every update is forwarded to the auth screen,
    which re-renders the symbol. Scanning the code on a signed-in device either
    completes the login or asks for the cloud password.
- **Data.** Only chats and user names are cached in memory. Messages live in
  the conversation controller, so moving between chats drops them.
- **Restart.** TDLib cannot be reused after `authorizationStateClosed` or after
  an interactive login flow is cancelled. The receive loop is stopped, the
  client destroyed, and a fresh one created, which is what makes "log out",
  "sign in again" and "back to phone number" work without relaunching the app.

### QR encoder

`PGQRCode.c` is dependency-free C: byte mode, error correction level M,
versions 1–10 (enough for a login link), Reed–Solomon over GF(256), all eight
masks with the standard penalty scoring. It is compiled into the app through
`PGQRCode.m` and rendered by `PGQRCodeView` with CoreGraphics.

The encoder is tested off-device:

```sh
python3 tools/verify_qr.py
```

The script compares every mask against `python-qrcode` and decodes the
automatically masked symbols with zbar.

### UI

| Controller | Responsibility |
|---|---|
| `PGRootViewController` | Swaps auth and split-view content on auth changes |
| `PGAuthViewController` | API keys, phone, code, password, registration |
| `PGSplitViewController` | Master/detail layout, always visible on iPad |
| `PGChatListViewController` | Chat list, unread badges, settings entry point |
| `PGConversationViewController` | History paging, composer, read receipts |
| `PGSettingsViewController` | Account, version, links, logout |

Cells do all layout in `layoutSubviews` with plain frames. There is no Auto
Layout in hot paths and no cell subclass that measures text during scrolling:
`PGMessage` stores a `PGMessageLayout` per table width.

## Data flow

```
updateNewMessage ──► PGClient ──► PGClientMessageReceivedNotification
                                      │
                    PGChatListViewController (chat preview + order)
                    PGConversationViewController (row insertion)
```

Requests:

```
PGConversationViewController ──► PGClient requestHistoryForChat:…
                                      │ @extra
                                      ▼
                                TDLib response
                                      │ completion block
                                      ▼
                                UI update
```

## Performance budget

- Chat list cell: fixed 68 pt height, four labels, one rounded avatar.
- Message cell: cached bubble/text/sender/time frames per width.
- Message pages: 40, hard cap 400 messages per conversation.
- Reload coalescing: 200 ms.
- TDLib: message database on, file database off, storage optimizer on.

## Build pipeline

```
scripts/build-tdlib.sh
  ├── host build:   prepare_cross_compiling  (TL generators)
  ├── OpenSSL:      ios64-cross, static libcrypto
  ├── TDLib:        CMake/iOS.cmake, arm64, iOS 12 deployment target
  └── libtool:      merge every .a into libtdjson_all.a

Makefile (Theos)
  └── clang, arm64, -mios-version-min=12.0, -force_load libtdjson_all.a

.github/workflows/build.yml
  └── cache .tdlib → make package → verify → .deb + unsigned .ipa
```

The TDLib cache key includes the hash of `scripts/build-tdlib.sh` and the
TDLib/OpenSSL versions, so changing the build script invalidates it on purpose.

## Deliberate trade-offs

- **No media layer.** A thumbnail pipeline is the main source of memory
  pressure and scroll jank on 1 GB devices. It is a separate project.
- **No APNs.** Push would require a server with a signing certificate. The app
  relies on MTProto updates while running.
- **Objective-C only.** No Swift runtime keeps the bundle smaller and avoids
  toolchain version drift on older SDKs.
