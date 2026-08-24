export const features = {
  eyebrow: "Your Mac. From your iPhone.",
  heroTitle: ["Your Mac,", "at your fingertips."],
  heroLead:
    "A precision trackpad, presentation remote, keyboard, media controller and shortcut deck — right from your iPhone.",
  ideaTitle: ["One iPhone.", "A whole new way", "to control your Mac."],
  ideaLead:
    "Kamihi Remote connects directly to your Mac over your local network. No separate mouse. No presentation clicker. No cloud account.",
  localTitle: ["Your cursor doesn't", "need the cloud."],
  localLead:
    "Kamihi Remote is designed to communicate directly between your iPhone and Mac on your local network.",
  reliabilityTitle: "Designed to stay connected.",
  finalTitle: ["Your Mac is already", "in your pocket."],
  finalLead: "Pick up your iPhone. Your Mac follows.",
};

export const gestures = [
  { fingers: "1 finger", action: "Move naturally", detail: "Pointer follows your touch." },
  { fingers: "Tap", action: "Click", detail: "Light tap to click. Hold to drag." },
  { fingers: "2 fingers", action: "Scroll in any direction", detail: "Natural two-finger scrolling." },
  { fingers: "2 fingers + pinch", action: "Zoom", detail: "Pinch to send zoom to the Mac." },
  { fingers: "3 fingers ↑", action: "Mission Control", detail: "Default. Remap in Settings." },
  { fingers: "3 fingers ← →", action: "Switch desktops", detail: "Swipe between Spaces." },
  { fingers: "3 fingers ↓", action: "App Exposé", detail: "See windows of the current app." },
  { fingers: "4 fingers ↓", action: "Show Desktop", detail: "Clear the board." },
];

export const reliability = [
  {
    title: "Automatic discovery",
    copy: "Find your Mac on the local network without memorizing an IP.",
  },
  {
    title: "Auto reconnect",
    copy: "Get back to controlling when Wi-Fi returns.",
  },
  {
    title: "Fail-safe input",
    copy: "A dropped connection will not leave your mouse held down.",
  },
  {
    title: "Local connection",
    copy: "Cursor motion stays between the two devices on the same network.",
  },
];

export const howItWorks = [
  {
    step: "01",
    title: "Install the Mac host",
    copy: "Open Kamihi Remote Host on your Mac. Allow Accessibility so it can move the cursor. A six-digit pairing code appears in the menu bar.",
  },
  {
    step: "02",
    title: "Open Kamihi on your iPhone",
    copy: "The iPhone looks for nearby Macs over Bonjour. You can also type the Mac’s local address.",
  },
  {
    step: "03",
    title: "Enter the pairing code",
    copy: "Match the code from the Mac, connect, and start controlling. The host can remember the last paired iPhone.",
  },
];

export const useCases = [
  { title: "At your desk", copy: "Lean back and still have a trackpad in your hand." },
  { title: "On the couch", copy: "Drive a living-room Mac without finding the mouse." },
  { title: "Across the room", copy: "Walk, talk, and still own the cursor." },
  { title: "During a presentation", copy: "Advance slides from anywhere in the room." },
  { title: "In a meeting", copy: "Pass control without passing a laptop." },
  { title: "On the road", copy: "A second pointing device that already lives in your pocket." },
];

export const showcase = [
  { id: "trackpad", label: "Trackpad" },
  { id: "landscape", label: "Landscape" },
  { id: "gestures", label: "Gestures" },
  { id: "slides", label: "Presentation" },
  { id: "keyboard", label: "Keyboard" },
  { id: "media", label: "Media" },
  { id: "deck", label: "Deck" },
] as const;

export const comingSoon = [
  {
    title: "Air Mouse",
    copy: "Point the iPhone in space to move the cursor. A setting exists; motion tracking is not shipping yet.",
  },
  {
    title: "Bluetooth",
    copy: "A Bluetooth fallback is planned. Today the link is local Wi-Fi.",
  },
];

export const nerdNotes = [
  "Bonjour service type _kamihiremote._tcp",
  "Hybrid transport: UDP for pointer motion, TCP for clicks, keys and commands",
  "Protocol v2 with session and sequence validation",
  "Heartbeat plus a 1.8s RELEASE_ALL watchdog",
  "Reconnect schedule 0.25s → 4s",
];
