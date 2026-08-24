import { useEffect, useState, type ReactNode } from "react";
import { comingSoon, features, gestures, nerdNotes, reliability } from "../content/features";
import { useInView, usePrefersReducedMotion } from "../lib/hooks";
import { Mac, Phone } from "./DeviceMockup";

function Reveal({ children }: { children: ReactNode }) {
  const [ref, inView] = useInView<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal${inView ? " in" : ""}`}>
      {children}
    </div>
  );
}

export function Idea() {
  return (
    <section className="section idea" id="features">
      <div className="wrap">
        <Reveal>
          <p className="kicker">
            <span className="star">✦</span> The idea
          </p>
          <h2 className="display">
            {features.ideaTitle[0]}
            <br />
            {features.ideaTitle[1]}
            <br />
            {features.ideaTitle[2]}
          </h2>
          <p className="lede">{features.ideaLead}</p>
        </Reveal>
      </div>
    </section>
  );
}

export function TrackpadSection() {
  return (
    <section className="section">
      <div className="wrap split">
        <Reveal>
          <p className="kicker">
            <span className="star">✦</span> Superpower #1
          </p>
          <h2 className="display">
            Your iPhone
            <br />
            becomes a trackpad.
          </h2>
          <p className="lede">
            One finger moves the pointer. Tap to click. Hold to drag. Two fingers scroll. It is the surface you already know, in your pocket.
          </p>
          <div className="gesture-list">
            <div className="gesture-row">
              <b>Move</b>
              <span>Slide one finger. The Mac cursor follows.</span>
            </div>
            <div className="gesture-row">
              <b>Click</b>
              <span>Tap. Optional haptic confirmation on the iPhone.</span>
            </div>
            <div className="gesture-row">
              <b>Right click</b>
              <span>Two-finger secondary click when you need it.</span>
            </div>
            <div className="gesture-row">
              <b>Drag</b>
              <span>Hold, then move. Mouse down stays down until you lift.</span>
            </div>
            <div className="gesture-row">
              <b>Scroll</b>
              <span>Two fingers, any direction, with natural scrolling.</span>
            </div>
          </div>
        </Reveal>
        <Phone screen="trackpad" />
      </div>
    </section>
  );
}

export function GestureDemo() {
  const [ref, inView] = useInView<HTMLDivElement>();
  const [count, setCount] = useState(1);
  const reduced = usePrefersReducedMotion();

  useEffect(() => {
    if (!inView || reduced) {
      setCount(3);
      return;
    }
    const id = window.setInterval(() => setCount((n) => (n % 3) + 1), 1600);
    return () => window.clearInterval(id);
  }, [inView, reduced]);

  return (
    <section className="section" id="gestures">
      <div className="wrap split reverse">
        <div ref={ref}>
          <div className="phone" role="img" aria-label="Glass orbs representing multi-finger Mac gestures">
            <div className="phone-screen">
              <div className="island" />
              <div className="app">
                <div className="app-header">
                  <div className="app-kicker">GESTURES</div>
                  <div className="host-row">
                    <span className="dot" />
                    {count} finger{count > 1 ? "s" : ""}
                  </div>
                </div>
                <div className="trackpad">
                  {Array.from({ length: count }, (_, i) => (
                    <span
                      key={i}
                      className="orb sm"
                      style={{
                        left: `${38 + i * 14}%`,
                        top: `${44 + (i % 2) * 10}%`,
                        animation: "none",
                      }}
                    />
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
        <Reveal>
          <p className="kicker">
            <span className="star">✦</span> Superpower #2
          </p>
          <h2 className="display">
            Gestures your
            <br />
            hands already know.
          </h2>
          <p className="lede">Make the gestures yours. Bind three- and four-finger swipes in Settings.</p>
          <div className="gesture-list">
            {gestures.map((row) => (
              <div className="gesture-row" key={row.fingers}>
                <b>{row.fingers}</b>
                <span>
                  {row.action}. {row.detail}
                </span>
              </div>
            ))}
          </div>
        </Reveal>
      </div>
    </section>
  );
}

export function LandscapeDemo() {
  const [ref, inView] = useInView<HTMLDivElement>();
  return (
    <section className="section">
      <div className="wrap">
        <Reveal>
          <p className="kicker">
            <span className="star">✦</span> Landscape
          </p>
          <h2 className="display">
            Turn it sideways.
            <br />
            Get even more space.
          </h2>
          <p className="lede">
            Landscape mode turns your entire iPhone into a wide, comfortable trackpad when you want maximum control.
          </p>
        </Reveal>
        <div className="rotate-stage" ref={ref}>
          <Phone wide={inView} screen={inView ? "landscape" : "trackpad"} />
        </div>
      </div>
    </section>
  );
}

export function PresentationDemo() {
  return (
    <section className="section">
      <div className="wrap split">
        <Reveal>
          <p className="kicker">
            <span className="star">✦</span> Superpower #3
          </p>
          <h2 className="display">
            Own the room.
            <br />
            Not the podium.
          </h2>
          <p className="lede">
            Previous, Next, Start, End, Black, and a pointer action. Profiles for Keynote, PowerPoint, and generic / Google Slides.
          </p>
        </Reveal>
        <Phone screen="slides" />
      </div>
    </section>
  );
}

export function KeyboardDemo() {
  return (
    <section className="section">
      <div className="wrap split">
        <Reveal>
          <p className="kicker">
            <span className="star">✦</span> Superpower #4
          </p>
          <h2 className="display">
            Your keyboard.
            <br />
            From across the room.
          </h2>
          <p className="lede">Command, Option, Control, Shift, Escape and arrows — plus a field that types to the Mac.</p>
          <Phone screen="keyboard" />
        </Reveal>
        <Reveal>
          <h2 className="display">And your media remote.</h2>
          <p className="lede">Play/pause, next, previous, volume and mute from the Media screen.</p>
          <Phone screen="media" />
        </Reveal>
      </div>
    </section>
  );
}

export function DeckDemo() {
  return (
    <section className="section">
      <div className="wrap split reverse">
        <Phone screen="deck" />
        <Reveal>
          <p className="kicker">
            <span className="star">✦</span> Superpower #5
          </p>
          <h2 className="display">
            Your favorite actions.
            <br />
            One tap away.
          </h2>
          <p className="lede">
            The Remote Deck ships with Safari, Finder, Music, Copy, Paste, Undo, Mission Control and desktop switches.
          </p>
        </Reveal>
      </div>
    </section>
  );
}

export function LocalFirst() {
  return (
    <section className="section">
      <div className="wrap">
        <Reveal>
          <h2 className="display">
            {features.localTitle[0]}
            <br />
            {features.localTitle[1]}
          </h2>
          <p className="lede">{features.localLead}</p>
          <p className="lede">No account required for core control. No remote cursor traffic through a cloud server.</p>
        </Reveal>
        <div className="local-visual">
          <div className="ghost-cloud" aria-hidden="true">
            Internet
          </div>
          <div className="local-row">
            <Phone screen="trackpad" />
            <svg width="180" height="80" viewBox="0 0 180 80" aria-hidden="true">
              <path d="M8 40 H172" stroke="rgba(120,144,208,0.7)" strokeWidth="2" />
              <circle className="packet" r="4" cy="40">
                <animate attributeName="cx" values="8;172;8" dur="3.2s" repeatCount="indefinite" />
              </circle>
            </svg>
            <Mac />
          </div>
        </div>
      </div>
    </section>
  );
}

export function ReliabilityDemo() {
  const reduced = usePrefersReducedMotion();
  const [phase, setPhase] = useState<"connected" | "searching">("connected");

  useEffect(() => {
    if (reduced) return;
    const id = window.setInterval(() => {
      setPhase((current) => (current === "connected" ? "searching" : "connected"));
    }, 3200);
    return () => window.clearInterval(id);
  }, [reduced]);

  return (
    <section className="section">
      <div className="wrap reli-grid">
        <Reveal>
          <h2 className="display">{features.reliabilityTitle}</h2>
          <div className="reli-points" style={{ marginTop: 40 }}>
            {reliability.map((item) => (
              <div key={item.title}>
                <h3>{item.title}</h3>
                <p>{item.copy}</p>
              </div>
            ))}
          </div>
          <details className="nerd">
            <summary>For nerds</summary>
            <ul>
              {nerdNotes.map((note) => (
                <li key={note}>{note}</li>
              ))}
            </ul>
          </details>
        </Reveal>
        <div className="conn" style={{ position: "relative" }}>
          <div className="status-chip" style={{ top: 8 }}>
            {phase === "connected" ? "Connected" : "Searching…"}
          </div>
          <svg viewBox="0 0 360 220" width="100%" height="220" aria-hidden="true">
            <circle cx="50" cy="160" r="18" fill="rgba(255,255,255,0.12)" />
            <rect x="292" y="132" width="48" height="36" rx="6" fill="rgba(255,255,255,0.12)" />
            {phase === "connected" ? (
              <>
                <path d="M68 150 C 140 40, 220 40, 292 148" stroke="#7890d0" strokeWidth="2" fill="none" />
                {!reduced ? (
                  <circle className="packet" r="4">
                    <animateMotion dur="2.2s" repeatCount="indefinite" path="M68 150 C 140 40, 220 40, 292 148" />
                  </circle>
                ) : null}
              </>
            ) : (
              <path
                d="M68 150 C 140 40, 220 40, 292 148"
                stroke="rgba(255,255,255,0.18)"
                strokeDasharray="6 8"
                fill="none"
              />
            )}
          </svg>
        </div>
      </div>
    </section>
  );
}

export function ComingSoon() {
  return (
    <section className="section-tight">
      <div className="wrap">
        <p className="kicker">
          <span className="star">✦</span> Next
        </p>
        <h2 className="display" style={{ fontSize: "clamp(36px, 5vw, 64px)" }}>
          Coming soon
        </h2>
        <div className="use-grid">
          {comingSoon.map((item) => (
            <div key={item.title}>
              <h3>
                {item.title} <span className="soon">Soon</span>
              </h3>
              <p>{item.copy}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
