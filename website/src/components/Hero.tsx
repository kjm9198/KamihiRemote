import { useEffect, useRef, useState } from "react";
import { features } from "../content/features";
import { usePrefersReducedMotion } from "../lib/hooks";
import { Mac, Phone } from "./DeviceMockup";

type Props = {
  ctaHref: string;
  ctaLabel: string;
  githubHref: string;
};

export function Hero({ ctaHref, ctaLabel, githubHref }: Props) {
  const reduced = usePrefersReducedMotion();
  const stage = useRef<HTMLDivElement>(null);
  const [tilt, setTilt] = useState({ x: 0, y: 0 });

  useEffect(() => {
    if (reduced) return;
    const node = stage.current;
    if (!node) return;
    const onMove = (event: PointerEvent) => {
      const box = node.getBoundingClientRect();
      const x = (event.clientX - box.left) / box.width - 0.5;
      const y = (event.clientY - box.top) / box.height - 0.5;
      setTilt({ x, y });
    };
    node.addEventListener("pointermove", onMove);
    return () => node.removeEventListener("pointermove", onMove);
  }, [reduced]);

  const phoneStyle = reduced
    ? undefined
    : {
        transform: `rotateY(${tilt.x * -8}deg) rotateX(${tilt.y * 6}deg) translate3d(${tilt.x * 10}px, ${tilt.y * 8}px, 0)`,
      };
  const macStyle = reduced
    ? undefined
    : {
        transform: `rotateY(${tilt.x * -4}deg) rotateX(${tilt.y * 3}deg) translate3d(${tilt.x * -6}px, ${tilt.y * 4}px, 0)`,
      };

  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero-grid">
        <div className="hero-copy">
          <p className="eyebrow">{features.eyebrow}</p>
          <h1 id="hero-title" className="display">
            {features.heroTitle[0]}
            <br />
            {features.heroTitle[1]}
          </h1>
          <p className="lede">{features.heroLead}</p>
          <div className="actions">
            <a className="btn btn-primary" href={ctaHref}>
              {ctaLabel}
            </a>
            <a className="btn btn-ghost" href={githubHref}>
              View on GitHub
            </a>
          </div>
        </div>
        <div className="hero-stage" ref={stage}>
          <div className="stage-link" aria-hidden="true">
            <svg viewBox="0 0 400 320" fill="none">
              <path
                d="M90 70 C 160 90, 210 170, 310 230"
                stroke="rgba(120,144,208,0.55)"
                strokeWidth="1.5"
                strokeDasharray="4 7"
              />
              {!reduced ? (
                <>
                  <circle className="packet" r="3.2" cx="0" cy="0">
                    <animateMotion dur="2.4s" repeatCount="indefinite" path="M90 70 C 160 90, 210 170, 310 230" />
                  </circle>
                  <circle className="packet" r="2.2" cx="0" cy="0">
                    <animateMotion dur="2.4s" begin="0.8s" repeatCount="indefinite" path="M90 70 C 160 90, 210 170, 310 230" />
                  </circle>
                </>
              ) : null}
            </svg>
          </div>
          <div className="hero-phone pointer-follow" style={phoneStyle}>
            <Phone screen="trackpad" label="iPhone running Kamihi Remote. A glass orb moves as a finger would." />
          </div>
          <div className="hero-mac pointer-follow" style={macStyle}>
            <Mac />
          </div>
        </div>
      </div>
    </section>
  );
}
