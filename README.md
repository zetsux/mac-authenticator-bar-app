# AuthenticatorBar

A small macOS menu bar app that generates time-based one-time passwords (TOTP, RFC 6238) for two-factor authentication. Click the shield icon (or press **Control + Option + O**) to see your codes, and click a code to copy it.

Everything stays on your Mac. The app makes no network requests.

## Features

- TOTP codes with SHA-1, SHA-256 and SHA-512, 6–8 digits, and custom periods
- Add accounts by QR code (screenshot from the clipboard, or drop an image file), by pasting an `otpauth://totp/...` URI, or by typing a Base32 secret
- Global hotkey (Control + Option + O) to open the popover from anywhere
- Copied codes are marked as concealed so clipboard managers skip them, and the clipboard is cleared after 30 seconds
- Optional launch at login
- Menu bar only, with no Dock icon

## Requirements

- macOS 13 or later
- Swift 5.9+ toolchain (Xcode or Command Line Tools)

## Build and run

```sh
./build.sh
open AuthenticatorBar.app
```

`build.sh` builds a release binary, generates the app icon, assembles `AuthenticatorBar.app` next to the script, and ad-hoc signs it. Drag the app into `/Applications` if you want to keep it.

Because the app is ad-hoc signed and not notarized, macOS Gatekeeper may block it if you download a copy built on another machine. Building it yourself avoids this.

To run the tests:

```sh
swift test
```

## Adding an account

1. Open the 2FA setup page that shows a QR code.
2. Take a screenshot of the QR with **⌘ ⌃ ⇧ 4** (this copies it to the clipboard).
3. Open AuthenticatorBar, choose to add an account, and click the paste-screenshot button.

You can also drop a QR image file onto the drop area, paste an `otpauth://` URI, or enter the Base32 secret by hand.

## How your secrets are stored

Accounts are stored as a single entry in the macOS Keychain (service `com.local.authenticatorbar`). Secrets are not written to disk in plain text, and they are not synced to iCloud by this app. The first time the app reads the Keychain, macOS may ask for permission; choose **Always Allow**.

If the Keychain cannot be read, the app refuses to save so that a failed read can never overwrite your stored accounts.

**Back up your secrets elsewhere.** If you lose this Mac or delete the Keychain entry, the accounts are gone, and you would have to re-enroll each service using its recovery codes.

## Project layout

| Path                           | Purpose                                                              |
| ------------------------------ | -------------------------------------------------------------------- |
| `Sources/AuthenticatorCore`    | Base32, TOTP, `otpauth://` parsing and QR decoding (no UI)           |
| `Sources/AuthenticatorBar`     | The menu bar app: SwiftUI views, Keychain storage, hotkey, clipboard |
| `Tests/AuthenticatorCoreTests` | Unit tests (RFC 6238 test vectors, URI parsing, QR decoding)         |
| `scripts/make_icon.swift`      | Generates the app icon during the build                              |
| `build.sh`                     | Builds and packages the `.app`                                       |

## Security notes

This is a personal project and has not been independently audited. It is fine for convenience, but if you rely on it for important accounts, keep your recovery codes somewhere safe and consider whether a mature, audited authenticator better fits your needs.

Anyone with access to your unlocked Mac session and your Keychain can read the stored secrets, as with any locally stored authenticator. Keeping your 2FA codes on the same device as your passwords also reduces the protection of two-factor authentication.
