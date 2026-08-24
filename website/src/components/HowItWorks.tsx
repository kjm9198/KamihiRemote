import { howItWorks, showcase, useCases } from "../content/features";
import { Phone, type PhoneScreen } from "./DeviceMockup";

const showcaseScreens: PhoneScreen[] = [
  "trackpad",
  "landscape",
  "gestures",
  "slides",
  "keyboard",
  "media",
  "deck",
];

export function HowItWorks() {
  return (
    <section className="section" id="how">
      <div className="wrap">
        <p className="kicker">
          <span className="star">✦</span> Setup
        </p>
        <h2 className="display">How it works</h2>
        <p className="lede">Three steps. A pairing code. Then your iPhone is the trackpad.</p>
        <div className="steps">
          {howItWorks.map((item) => (
            <div key={item.step}>
              <div className="step-num">{item.step}</div>
              <h3>{item.title}</h3>
              <p>{item.copy}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function Showcase() {
  return (
    <section className="section-tight" aria-labelledby="showcase-title">
      <div className="wrap">
        <h2 id="showcase-title" className="display" style={{ fontSize: "clamp(36px, 5vw, 64px)" }}>
          Every surface, in your hand.
        </h2>
        <p className="lede">Trackpad, landscape, gestures, slides, keyboard, media, deck.</p>
      </div>
      <div className="showcase-row">
        {showcase.map((item, index) => (
          <div key={item.id} style={{ scrollSnapAlign: "center" }}>
            <Phone screen={showcaseScreens[index] ?? "trackpad"} wide={item.id === "landscape"} label={item.label} />
          </div>
        ))}
      </div>
    </section>
  );
}

export function UseCases() {
  return (
    <section className="section">
      <div className="wrap">
        <p className="kicker">
          <span className="star">✦</span> Places
        </p>
        <h2 className="display">
          Built for people who
          <br />
          use a Mac everywhere.
        </h2>
        <div className="use-grid">
          {useCases.map((item) => (
            <div key={item.title}>
              <h3>{item.title}</h3>
              <p>{item.copy}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
