# Kamihi Desktop

Kamihi Desktop turns an iPhone into a desktop-class workspace for an external display such as the RayNeo Air 4 Pro.

The iPhone is the computer and controller. The external display is the desktop canvas. There is no Mac host, no Mac pairing, no local-network remote-control product, and no Remote-for-Mac launch mode.

## Product flow

1. Open Kamihi Desktop on iPhone.
2. Choose a startup profile: Clean Desktop, Resume, Work, Browse, Media, or optional Vibe.
3. Connect an external display over the iPhone's supported display output.
4. Use the phone as the full-screen trackpad/controller; Keyboard and More remain the only persistent controls.
5. Use Kamihi-owned desktop windows, Browser, Files, Notes, Photos, Calculator, Settings, clipboard, window management and supported web apps on the external canvas.

Kamihi Desktop uses public iOS APIs and follows an iOS/iPadOS-inspired Kamihi design system. It aims for familiar desktop ergonomics without copying macOS or Samsung proprietary assets or trade dress.

## Development

Requirements: Xcode 26+ and an iOS 26+ simulator/device.

Open `KamihiRemote.xcodeproj` and run the single iOS scheme currently named `KamihiRemote`. The historical internal scheme/bundle identifier is retained temporarily for upgrade/data-container continuity; the shipped product and display name are Kamihi Desktop.

CI validates:

- the iOS Simulator build;
- the trackpad-first controller contract;
- Desktop Lab launch/render evidence on an iPhone Simulator.

No macOS host target is built or shipped.

## External display notes

Kamihi Desktop uses the display mode negotiated by iOS. It may target a 1920×1080 16:9 desktop when the connected hardware exposes that mode, but it does not force unsupported resolution or refresh rates. RayNeo-specific resolution, refresh, overscan, reconnect, latency and long-session power behavior require physical verification on real hardware.

## Privacy

Kamihi Desktop does not require a Mac connection. Authentication remains inside public iOS/WebKit flows. The app must never read, store or log raw passwords or credentials. Files, Photos and sharing use public Apple pickers/permission/share surfaces where applicable.

## License

Private repository. All rights reserved unless a license file is added later.
