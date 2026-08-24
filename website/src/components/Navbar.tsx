import { useEffect, useState } from "react";
import { Link, NavLink } from "react-router-dom";
import { asset, githubRepo, product, withBase } from "../content/site";

const links = [
  { href: "#features", label: "Features" },
  { href: "#gestures", label: "Gestures" },
  { href: "#how", label: "How it works" },
  { href: "#faq", label: "FAQ" },
];

type Props = {
  ctaHref: string;
  ctaLabel: string;
};

export function Navbar({ ctaHref, ctaLabel }: Props) {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 16);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header>
      <nav className={`nav${scrolled ? " is-scrolled" : ""}`} aria-label="Primary">
        <Link className="brand" to="/" onClick={() => setOpen(false)}>
          <img src={asset("app-icon.png")} width={28} height={28} alt="" />
          {product.name.toUpperCase()}
        </Link>
        <div className="nav-links">
          {links.map((link) => (
            <a key={link.href} href={withBase(link.href)}>
              {link.label}
            </a>
          ))}
        </div>
        <div className="nav-cta">
          <a className="btn btn-ghost" href={githubRepo}>
            GitHub
          </a>
          <a className="btn btn-primary" href={ctaHref}>
            {ctaLabel}
          </a>
        </div>
        <button
          className="menu-toggle"
          type="button"
          aria-expanded={open}
          aria-controls="mobile-menu"
          onClick={() => setOpen((value) => !value)}
        >
          <span className="sr-only">{open ? "Close menu" : "Open menu"}</span>
          {open ? "✕" : "☰"}
        </button>
        {open ? (
          <div className="nav-drawer" id="mobile-menu">
            {links.map((link) => (
              <a key={link.href} href={withBase(link.href)} onClick={() => setOpen(false)}>
                {link.label}
              </a>
            ))}
            <a href={githubRepo}>GitHub</a>
            <a href={ctaHref}>{ctaLabel}</a>
            <NavLink to="/privacy" onClick={() => setOpen(false)}>
              Privacy
            </NavLink>
          </div>
        ) : null}
      </nav>
    </header>
  );
}
