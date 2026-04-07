# BoothGuard

Lock your laptop at a conference booth without losing your displays.

BoothGuard is a macOS menu bar app that suppresses keyboard, trackpad, and
mouse input while leaving every connected display fully visible — perfect for
running demos or videos on external monitors while you step away from a
conference booth. Unlock by typing a PIN on the laptop keyboard. Future
phases add phone-based unlock and tamper-alert push notifications.

## Repository Layout

```
boothguard/
├── apps/
│   └── macos/                # Phase 1: standalone Mac app (Swift Package)
│       ├── Sources/
│       │   ├── BoothGuardApp/    # Executable target (AppKit + SwiftUI)
│       │   └── BoothGuardCore/   # Pure logic — PIN, state machine
│       ├── Tests/
│       └── Package.swift
└── specs/
    └── SPEC.md
```

Phases 2–4 add a Flutter mobile app, an end-to-end encrypted message
protocol, a WebSocket relay, and push notifications. Those will land under
`apps/mobile/`, `services/relay/`, and `packages/protocol/` on follow-up
branches.

## Building & Running (Phase 1)

```sh
cd apps/macos
swift build
swift run BoothGuard
```

On first launch macOS will prompt for **Accessibility** and **Input
Monitoring** permission. Both are required: Accessibility lets BoothGuard
create a session-level event tap, and Input Monitoring lets it observe
keystrokes globally so the PIN buffer can receive them while locked.

Open **Settings…** from the menu bar to set a PIN before locking for the
first time.

## Tests

```sh
cd apps/macos
swift test
```

`BoothGuardCore` is intentionally platform-agnostic so its PIN hashing,
validation, and lock-state-machine logic can be unit tested without a Mac
display, an event tap, or the Keychain.

## Status

- [x] Phase 1 — Mac App Core (this branch)
- [ ] Phase 2 — Pairing & local unlock
- [ ] Phase 3 — Cloud relay & push notifications
- [ ] Phase 4 — Polish (tamper photos, branding, panic mode)
