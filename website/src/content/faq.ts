export const faq = [
  {
    q: "What is Kamihi Remote?",
    a: "Kamihi Remote is an iPhone app plus a Mac menu-bar host. Together they turn your iPhone into a trackpad, presentation remote, keyboard, media controller and shortcut deck for your Mac.",
  },
  {
    q: "Does it need the Internet?",
    a: "No. Core control talks directly between your iPhone and Mac on the local network. There is no Kamihi cloud account and cursor traffic is not routed through a Kamihi server.",
  },
  {
    q: "Do my iPhone and Mac need to be on the same Wi-Fi?",
    a: "Yes. The current release discovers and connects over the local network. The devices need to reach each other on that network.",
  },
  {
    q: "Does it work over Bluetooth?",
    a: "Not yet. Bluetooth fallback is planned. Today the connection is local Wi-Fi.",
  },
  {
    q: "Which gestures are supported?",
    a: "One-finger move, tap-to-click, hold-to-drag, two-finger scroll, pinch zoom, three-finger Mission Control / desktop / App Exposé swipes, and four-finger Show Desktop. Gesture bindings are configurable in Settings.",
  },
  {
    q: "Is Windows supported?",
    a: "Kamihi Remote currently focuses on iPhone + macOS.",
  },
  {
    q: "Does the Mac app need Accessibility permission?",
    a: "Yes. macOS only lets trusted apps inject cursor and keyboard events. Kamihi Remote Host asks for Accessibility so it can move the pointer, click, scroll and type on your Mac — locally, on that Mac.",
  },
  {
    q: "Can I use it for presentations?",
    a: "Yes. The Presentation screen includes Previous, Next, Start, End, Black and a pointer action, with profiles for Keynote, PowerPoint, and generic / Google Slides.",
  },
  {
    q: "Does Kamihi Remote collect what I type?",
    a: "The apps do not include analytics or crash-reporting SDKs. Typed text is sent over the local network to your Mac so it can be entered there. It is not uploaded to Kamihi. Preferences, the pairing code, and paired-host details stay in on-device storage.",
  },
  {
    q: "What versions do I need?",
    a: "The current project targets iOS 26+ and macOS 26+.",
  },
];
