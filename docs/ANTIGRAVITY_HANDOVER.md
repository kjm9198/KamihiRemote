# Antigravity handover — KamihiRemote

**Repo:** https://github.com/kjm9198/KamihiRemote  
**Branch to use:** `main`  
**Owner device:** Michael’s physical **iPhone 17** (`kjm9198`), Mac host on this machine (`MP9198`)

This is a native Xcode project (iOS remote + macOS host). Do **not** only build the simulator and call it done when Michael asks to test — install on the **physical iPhone**.

---

## What the product is

- **KamihiRemote** (`com.kamihi.remote`) — iPhone controller
- **KamihiRemoteHost** (`com.kamihi.remote.host`) — Mac input injector (Accessibility required)

Flow that must work end-to-end:

`iPhone touch/Deck` → `RemoteCommand` → `TCP` (reliable) / `UDP` (MOVE/SCROLL) → Mac `InputEngine` → real cursor/keys/Spaces

---

## Critical gestures (do not invert)

| Gesture | Mac action |
|---|---|
| **3-finger swipe LEFT** | **Control + Left Arrow** (Previous Desktop) |
| **3-finger swipe RIGHT** | **Control + Right Arrow** (Next Desktop) |
| 3-finger up | Mission Control |
| 3-finger down | App Exposé |
| 1-finger move / tap | pointer + left click |
| **2-finger tap only** | Options / right-click (not one finger) |

Bindings live in `Shared/AppPreferences.swift` (`threeFingerLeft = previousDesktop`, `threeFingerRight = nextDesktop`). Execution is `macOS/InputEngine.swift` → `performDesktop` → `CGEvent` Control+Arrow.

Mac System Settings must have Mission Control shortcuts enabled:

**System Settings → Keyboard → Keyboard Shortcuts → Mission Control → Move left/right a Space = ⌃← / ⌃→**

---

## How to find / wake the physical iPhone

`xctrace` often shows the phone as “Offline” even when CoreDevice can use it. Prefer **`devicectl`**:

```bash
xcrun devicectl list devices
```

Look for something like:

```text
kjm9198   ...   available (paired)   iPhone 17
```

Use the **CoreDevice Identifier** (UUID), not only the hardware UDID.

If it is missing:

1. Unlock the iPhone
2. Keep it awake / on the Lock screen Trusted state
3. USB cable preferred (Wi‑Fi CoreDevice also works if previously paired)
4. Trust this Mac if prompted
5. Retry `xcrun devicectl list devices`

Example device id used successfully before:

`2B445E34-13DC-57D9-9A1C-32BC838E96D5`

---

## Build + install iPhone (physical) — copy/paste

From repo root `/Users/kjm9198/KamihiRemote`:

```bash
cd /Users/kjm9198/KamihiRemote
git fetch origin && git checkout main && git pull origin main

DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | awk '/kjm9198/ && /available/ {print $(NF-3)}')"
# If awk fails, set explicitly:
# DEVICE_ID="2B445E34-13DC-57D9-9A1C-32BC838E96D5"

xcodebuild \
  -project KamihiRemote.xcodeproj \
  -scheme KamihiRemote \
  -configuration Debug \
  -derivedDataPath .derivedData \
  -destination "id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  build

xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  .derivedData/Build/Products/Debug-iphoneos/KamihiRemote.app

xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  --console \
  com.kamihi.remote
```

Confirm:

- Console shows `Kamihi gesture self-checks passed` (must NOT `Precondition failed` / signal 5)
- Process stays alive:

```bash
xcrun devicectl device info processes --device "$DEVICE_ID" | rg -i Kamihi
```

Signing team in project: `QBAGFXM25Q` (Apple Development). First launch may need **Settings → General → VPN & Device Management → trust developer**.

---

## Build + install Mac host

```bash
cd /Users/kjm9198/KamihiRemote

xcodebuild \
  -project KamihiRemote.xcodeproj \
  -scheme KamihiRemoteHost \
  -sdk macosx \
  -configuration Debug \
  -derivedDataPath .derivedData \
  build

pkill -f KamihiRemoteHost || true
rm -rf /Applications/KamihiRemoteHost.app
cp -R .derivedData/Build/Products/Debug/KamihiRemoteHost.app /Applications/KamihiRemoteHost.app
open -n /Applications/KamihiRemoteHost.app
```

On first run / after OS updates:

1. Open **Kamihi Remote Host**
2. Grant **Accessibility** when prompted (green/trusted)
3. Note the **pairing code** on the host window
4. Leave host running on the same Wi‑Fi as the phone

---

## Connect phone ↔ Mac (for Michael’s test)

1. Mac: host running, Accessibility OK, pairing code visible  
2. iPhone: open **Kamihi**  
3. If not auto-connected: **Settings (gear)** → enter pairing code → Connect / pick discovered Mac  
4. Status should become **connected**  
5. Quick prove path:
   - Move one finger → Mac cursor moves (UDP)
   - Deck **Desktop →** → Space changes + banner (TCP + ACK)
   - **3-finger swipe right/left** → Control+Arrow Spaces
   - Deck bottom strip is a trackpad while using tiles

UDP MOVE can work while TCP Deck is dead — if Deck fails but cursor moves, fix TCP lifecycle / reconnect, do not claim “connected = healthy”.

---

## Deck / agent workflow (current main)

Default tiles include: Copy, Paste, Select All, Select Line, Cursor, ChatGPT, Finder, Dictate, Desktop ←/→, Mission, Undo.

- Bottom of Deck = live trackpad
- **Dictate**: mic → text → Send (types on Mac + Return) for Cursor/ChatGPT prompts
- iOS must allow **Microphone** + **Speech Recognition**

---

## Do / Don’t for Antigravity

**Do**

- Pull latest `main` before testing
- Install **iphoneos** build on physical `kjm9198`
- Also refresh `/Applications/KamihiRemoteHost.app`
- Trace failures: iPhone command → TCP/UDP → Mac parse → InputEngine

**Don’t**

- Stop after Simulator-only install when Michael wants a real test
- Treat `xctrace … Offline` as “no phone” without checking `devicectl`
- Invert 3-finger left/right bindings
- Crash the app with DEBUG `precondition` self-checks (they must soft-fail)

---

## Useful paths

| Path | Role |
|---|---|
| `iOS/KamihiRemoteApp.swift` | App entry → `KamihiPolishedRootView` |
| `iOS/RemoteSession.swift` | Connection, ACK, send path |
| `iOS/ReliableClient.swift` | TCP lifecycle |
| `iOS/GestureEngine.swift` | Multi-touch state machine |
| `iOS/FeatureScreens.swift` | Deck + bottom trackpad |
| `iOS/KeyboardOverlayDock.swift` | Live text + Dictate sheet |
| `macOS/HostSession.swift` | Host TCP command handling |
| `macOS/InputEngine.swift` | CGEvent injection |
| `Shared/RemoteCommand.swift` / `RemotePacket.swift` | Wire protocol |

DerivedData for local builds: repo `.derivedData/` (gitignored).
