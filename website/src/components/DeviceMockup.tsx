export type PhoneScreen =
  | "trackpad"
  | "landscape"
  | "gestures"
  | "slides"
  | "keyboard"
  | "media"
  | "deck"
  | "settings";

const tabs = ["trackpad", "slides", "keyboard", "media", "deck"] as const;

function Tabs({ active }: { active: string }) {
  return (
    <div className="tabbar" aria-hidden="true">
      {tabs.map((tab) => (
        <span key={tab} className={`tab${tab === active ? " on" : ""}`} />
      ))}
      <span className="tab" />
    </div>
  );
}

function Header({ host = "Studio Mac" }: { host?: string }) {
  return (
    <div className="app-header">
      <div className="app-kicker">KAMIHI REMOTE</div>
      <div className="host-row">
        <span className="dot" />
        {host}
      </div>
      <div className="quality">Excellent</div>
    </div>
  );
}

export function Phone({
  screen = "trackpad",
  wide = false,
  label,
}: {
  screen?: PhoneScreen;
  wide?: boolean;
  label?: string;
}) {
  const landscape = wide || screen === "landscape";
  return (
    <div
      className={`phone${landscape ? " is-wide" : ""}`}
      role="img"
      aria-label={label ?? `iPhone showing the Kamihi ${screen} screen`}
    >
      <div className="phone-screen">
        <div className="island" />
        <div className={`app${landscape ? " landscape" : ""}`}>
          {landscape ? (
            <>
              <div className="rail">
                <div className="app-kicker" style={{ writingMode: "vertical-rl" }}>
                  KAMIHI
                </div>
                {tabs.map((tab) => (
                  <span key={tab} className={`tab${tab === "trackpad" ? " on" : ""}`} />
                ))}
              </div>
              <div className="trackpad" style={{ flex: 1 }}>
                <span className="orb hero-orb" style={{ animation: "none", left: "46%", top: "48%" }} />
              </div>
            </>
          ) : (
            inner(screen)
          )}
        </div>
      </div>
    </div>
  );
}

function inner(screen: PhoneScreen) {
  switch (screen) {
    case "slides":
      return (
        <>
          <div className="screen-label">PRESENTATION</div>
          <div className="pres-grid">
            <div className="glass-btn">Previous</div>
            <div className="glass-btn">Next</div>
          </div>
          <div className="small-row">
            <div className="glass-btn">Start</div>
            <div className="glass-btn">Black</div>
            <div className="glass-btn">End</div>
          </div>
          <Tabs active="slides" />
        </>
      );
    case "keyboard":
      return (
        <>
          <div className="screen-label">KEYBOARD</div>
          <div className="keys">
            {["⌘", "⌥", "⌃", "⇧", "esc", "←", "↑", "↓", "→"].map((key) => (
              <div className="key" key={key}>
                {key}
              </div>
            ))}
          </div>
          <Tabs active="keyboard" />
        </>
      );
    case "media":
      return (
        <>
          <div className="screen-label">MEDIA</div>
          <div className="media-row">
            <div className="glass-btn">⏮</div>
            <div className="glass-btn">⏯</div>
            <div className="glass-btn">⏭</div>
          </div>
          <div className="small-row">
            <div className="glass-btn">Vol −</div>
            <div className="glass-btn">Mute</div>
            <div className="glass-btn">Vol +</div>
          </div>
          <Tabs active="media" />
        </>
      );
    case "deck":
      return (
        <>
          <div className="screen-label">DECK</div>
          <div className="deck-grid">
            {["Safari", "Finder", "Music", "Copy", "Paste", "Undo", "Desk ←", "Mission", "Desk →"].map((title) => (
              <div className="glass-btn" key={title}>
                {title}
              </div>
            ))}
          </div>
          <Tabs active="deck" />
        </>
      );
    case "gestures":
      return (
        <>
          <Header />
          <div className="trackpad">
            <span className="orb sm" style={{ left: "38%", top: "42%" }} />
            <span className="orb sm" style={{ left: "52%", top: "46%" }} />
            <span className="orb sm" style={{ left: "46%", top: "58%" }} />
          </div>
          <Tabs active="trackpad" />
        </>
      );
    case "settings":
      return (
        <>
          <div className="screen-label">SETTINGS</div>
          <div className="keys">
            {["Precision", "Natural scroll", "Haptics", "Auto connect"].map((row) => (
              <div className="key" key={row} style={{ width: "100%" }}>
                {row}
              </div>
            ))}
          </div>
          <Tabs active="trackpad" />
        </>
      );
    default:
      return (
        <>
          <Header />
          <div className="trackpad">
            <span className="orb hero-orb" />
          </div>
          <Tabs active="trackpad" />
        </>
      );
  }
}

export function Mac() {
  return (
    <div className="mac" aria-hidden="true">
      <div className="mac-bezel">
        <div className="mac-screen">
          <svg className="mac-cursor hero-cursor" viewBox="0 0 14 18">
            <path fill="#f7f8fc" d="M1 1l11 9.2-5.1.4 2.6 6.4-2.2.9-2.6-6.4L1 17z" />
          </svg>
        </div>
        <div className="mac-chin" />
      </div>
      <div className="mac-foot" />
    </div>
  );
}
