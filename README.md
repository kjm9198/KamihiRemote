# Kamihi Remote

Turn an iPhone into a local-network trackpad, presentation remote, keyboard, media controller and shortcut deck for a Mac.

Current version: **0.2.0**  
Targets: **iOS 26+** and **macOS 26+**

- iPhone app: precision trackpad, Mac-like gestures, landscape mode, presentation / keyboard / media / deck screens, Bonjour discovery, pairing code, haptics
- Mac host: menu-bar app, Accessibility cursor injection, hybrid UDP + TCP, reconnect, fail-safe `RELEASE_ALL`

This is a local-first product. Core control talks directly between the two devices on your network. There is no Kamihi cloud account.

## Marketing site

The product site lives in [`website/`](website/) and deploys to GitHub Pages.

- Preview (after Pages is enabled): `https://kjm9198.github.io/KamihiRemote/`
- Source: this repository

```bash
cd website
npm install
npm run dev
npm run build
```

GitHub Pages builds on push to `main` via [`.github/workflows/pages.yml`](.github/workflows/pages.yml). Native Xcode targets are not part of that workflow.

To use a custom domain later (`kamihiremote.com` or `remote.kamihi.com`):

1. Add a `CNAME` in `website/public/`
2. Set `BASE_PATH=/` in the Pages workflow
3. Point the domain at GitHub Pages

Until a GitHub Release exists, the site CTA is **Get the beta** and links to [Releases](https://github.com/kjm9198/KamihiRemote/releases). Tagging `v0.2.0` (or any `v*`) creates a categorized GitHub Release via [`.github/workflows/release.yml`](.github/workflows/release.yml). Attach signed Mac/iOS builds to that release from Xcode.

## Run on a Mac and iPhone

You need Xcode 26, an Apple Developer team, and a physical iPhone on the same Wi-Fi as the Mac.

1. Open `KamihiRemote.xcodeproj`
2. Select the **KamihiRemoteHost** scheme → your Mac → Run  
   Allow Accessibility when asked. The pairing code appears in the menu bar.
3. Select the **KamihiRemote** iOS scheme → your iPhone → Run  
   Allow Local Network. Enter the pairing code (or pick the discovered Mac).
4. Move a finger on the trackpad. The Mac cursor should follow.

Bonjour service: `_kamihiremote._tcp`  
UDP `49731` · TCP `49732`

## What ships vs coming soon

Ships in 0.2: trackpad, tap / right-click / drag / scroll / pinch, 3–4 finger system gestures (configurable), landscape, Keynote / PowerPoint / generic presentation profiles, keyboard, media, Remote Deck, Bonjour, reconnect, heartbeat + `RELEASE_ALL` watchdog, menu-bar host, launch at login.

Coming soon: **Air Mouse** (setting exists, motion tracking is not implemented) and **Bluetooth** fallback.

## Privacy

See the site privacy page. The apps do not include analytics SDKs. Preferences, pairing code and paired-host details stay on device. Typed text is sent over the local network to the paired Mac only.

## License

Private repository. All rights reserved unless a license file is added later.
