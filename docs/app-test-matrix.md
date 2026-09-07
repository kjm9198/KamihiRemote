# Kamihi Desktop App Test Matrix

This matrix tracks the app-by-app bug-fix loop. `VERIFIED` means the flow is covered by current software evidence; `PARTIAL` means useful functionality exists but important flows remain unverified or incomplete; `PENDING` means it has not yet received a dedicated deep app run. Real-device and RayNeo-only behavior remains `NEEDS PHYSICAL TEST` until tested on hardware.

Canonical product direction: one persistent iPhone-owned desktop, trackpad-first phone controller, no user-facing Remote-for-Mac product path, and no automatic app/window movement.

| App / surface | Open / restore / X lifecycle | Controls + content | Pointer / scroll | Keyboard | Empty / error / permission states | Persistence / reopen | Remaining app-specific work |
|---|---|---|---|---|---|---|---|
| Browser | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | Dedicated run 2026-09-07 verified tabs, close/new-tab, address/search, back/forward/reload-stop, favorites/bookmarks/history, find, share, downloads/new-window routing and persistent WebKit store in source. Removed false macOS Safari user-agent impersonation so sites see the real iOS/WKWebView runtime while desktop layout remains requested through public WebKit APIs. Still needs targeted simulator/UI coverage for button flows and physical Password AutoFill/passkeys/CAPTCHA/SSO/file upload/media tests. |
| Photos | PARTIAL | PARTIAL | PENDING | N/A | PARTIAL | PENDING | Current main has native PhotoKit library/favorites/recent, detail viewing, favorite/delete, Limited Library support and permission states. Next dedicated run: verify launcher/dock open, grid/detail buttons, limited/denied recovery, share/export and reopen. |
| Files | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | Deep import/preview/share/delete/reopen test pending. |
| PDF Viewer | PENDING | PENDING | PENDING | N/A | PENDING | PENDING | Deep open/scroll/share/error-state test pending. |
| Documents | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | Deep create/select/edit/import/export/reopen test pending. |
| Sheets | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | Deep lifecycle first; then range selection/copy/paste, editing, rows/columns, formulas and CSV workflows. |
| Notes | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | Deep create/select/edit/delete/reopen test pending. |
| Calculator | PENDING | PENDING | N/A | PENDING | PENDING | PENDING | Every keypad/control and parser error-state test pending. |
| Clipboard | PENDING | PENDING | PENDING | PENDING | PENDING | N/A | Refresh/copy/paste/Notes/share/clear behavior test pending; history is intentionally memory-only. |
| ChatGPT | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | WebView load/auth/input/recovery/takeover test pending. |
| YouTube | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | Load/playback/media/fullscreen/navigation/recovery test pending. |
| Settings | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | Every control and persistence test pending. |
| Phone Takeover / auth | PENDING | PENDING | N/A | PENDING | PENDING | PARTIAL | Real auth remains public WebKit/iOS only; never copy/log raw passwords, passkeys, cookies or tokens. |
| App Library / launcher | PENDING | PENDING | PENDING | N/A | PARTIAL | PENDING | Verify every app tile opens/restores the intended window and never resets existing geometry. |
| Dock | PENDING | PENDING | PENDING | N/A | PENDING | PENDING | Verify every pinned/running icon, close/reopen state and auto-hide behavior. |
| Display Diagnostics | PENDING | PENDING | PENDING | N/A | PENDING | PENDING | Software controls plus physical RayNeo calibration remain. |

## Cross-app invariants

Every dedicated run must verify, where applicable: tap app -> visible window; reopening an existing app -> restore/activate without geometry reset; X -> window is actually removed; minimize/maximize -> deterministic; no minimized/invisible window owns keyboard or scrolling; two-finger vertical movement scrolls rather than resizing; visible buttons perform their advertised action; reconnect preserves a usable persistent desktop.
