import { useId, useState } from "react";
import { NavLink } from "react-router-dom";
import { faq } from "../content/faq";
import { features } from "../content/features";
import { githubRepo, product } from "../content/site";

export function FAQ() {
  const [open, setOpen] = useState<number | null>(0);
  const baseId = useId();

  return (
    <section className="section" id="faq">
      <div className="wrap">
        <p className="kicker">
          <span className="star">✦</span> FAQ
        </p>
        <h2 className="display">Questions, answered.</h2>
        <div className="faq-list">
          {faq.map((item, index) => {
            const expanded = open === index;
            const panelId = `${baseId}-${index}`;
            return (
              <div className="faq-item" key={item.q}>
                <button
                  type="button"
                  aria-expanded={expanded}
                  aria-controls={panelId}
                  onClick={() => setOpen(expanded ? null : index)}
                >
                  {item.q}
                  <span className="plus" aria-hidden="true">
                    {expanded ? "–" : "+"}
                  </span>
                </button>
                {expanded ? (
                  <p id={panelId}>{item.a}</p>
                ) : (
                  <p id={panelId} hidden>
                    {item.a}
                  </p>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

export function FinalCTA({ ctaHref, ctaLabel }: { ctaHref: string; ctaLabel: string }) {
  return (
    <section className="cta-block" aria-labelledby="final-title">
      <div className="wrap">
        <h2 id="final-title" className="display">
          {features.finalTitle[0]}
          <br />
          {features.finalTitle[1]}
        </h2>
        <p className="lede">{features.finalLead}</p>
        <div className="orb-stage" aria-hidden="true">
          <div className="float-orb" />
        </div>
        <div className="actions" style={{ justifyContent: "center" }}>
          <a className="btn btn-primary" href={ctaHref}>
            {ctaLabel}
          </a>
          <a className="btn btn-ghost" href={githubRepo}>
            View source on GitHub
          </a>
        </div>
      </div>
    </section>
  );
}

export function Footer() {
  return (
    <footer>
      <div className="wrap footer">
        <div>
          {product.name}
          <br />
          Built by {product.studio}
          <br />© {product.year} {product.studio}
        </div>
        <nav aria-label="Footer">
          <a href={githubRepo}>GitHub</a>
          <NavLink to="/privacy">Privacy</NavLink>
        </nav>
      </div>
    </footer>
  );
}
