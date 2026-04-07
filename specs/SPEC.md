# BoothGuard

**Tagline:** Lock your laptop at a conference booth without losing your displays.

**Repository:** Monorepo containing a macOS menu bar app, a Flutter mobile app (iOS + Android), and a lightweight WebSocket relay service.

## Problem

Conference booth staff need to step away from their laptops (bathroom breaks, grabbing coffee, chatting with attendees) while keeping external monitors running videos, demos, or information pages. macOS screen lock blanks all displays. There is no good tool that locks input while preserving visual output across all connected screens.

## Solution

A macOS app that intercepts and suppresses all keyboard, trackpad, and mouse input while keeping displays fully visible and active. Unlock via a paired mobile phone or a PIN typed on the keyboard. Tamper attempts trigger push notifications to the owner's phone.

---

## Phase 1 — Mac App Core (Standalone)

This branch implements Phase 1: a fully standalone macOS app with PIN-only
unlock. See the full spec — including Phases 2–4, the encrypted message
protocol, the relay server, and push notifications — in the project README and
follow-up branches.

### 1.1 Menu Bar App

- No Dock icon (`LSUIElement = true`, set via `setActivationPolicy(.accessory)`).
- Status item with a lock glyph (filled when locked, outlined when unlocked).
- Dropdown: **Lock**, **Settings…**, **Quit** (Quit disabled while locked).

### 1.2 Event Tap (Input Suppression)

- `CGEvent.tapCreate` with `.cgSessionEventTap`, `.headInsertEventTap`,
  `.defaultTap` over the keyboard, mouse, trackpad, and scroll wheel event
  mask.
- Returns `nil` for all events while locked except digit keystrokes and
  Return, which are routed into the PIN entry buffer.
- Re-enables itself on `.tapDisabledByTimeout` / `.tapDisabledByUserInput`.
- Onboarding requests Accessibility + Input Monitoring permissions.

### 1.3 Lock Screen Overlay

- `NSPanel` (`.nonactivatingPanel`, `.screenSaver` level,
  `.canJoinAllSpaces`, `.fullScreenAuxiliary`).
- Semi-transparent black background, lock glyph, customizable message, and
  "Enter PIN to unlock" hint.
- Targets only the built-in display by default (matched against
  `CGMainDisplayID()`); user can opt to lock all displays.

### 1.4 PIN Unlock

- PIN stored in the macOS Keychain, hashed with a salted, iterated SHA-256
  construction (stand-in for bcrypt/Argon2 to avoid third-party deps).
- Buffer fed by digit keystrokes; Return submits.
- 5 failed attempts triggers a 30 s cooldown that doubles on each subsequent
  set of 5 failures.
- 4–8 digits.

### 1.5 Settings (SwiftUI)

- Set / change PIN (requires current PIN if one already exists).
- Lock screen message.
- Lock all displays vs built-in only.
- Launch at login toggle.

---

The repository layout, Phases 2–4, encrypted protocol design, relay service,
push notification flow, and security threat model are documented in the
project's main `README.md` and tracked on follow-up feature branches.
