import { useEffect, useState } from "react";
import {
  ComingSoon,
  DeckDemo,
  GestureDemo,
  Idea,
  KeyboardDemo,
  LandscapeDemo,
  LocalFirst,
  PresentationDemo,
  ReliabilityDemo,
  TrackpadSection,
} from "../components/FeatureSection";
import { FAQ, FinalCTA, Footer } from "../components/FAQ";
import { Hero } from "../components/Hero";
import { HowItWorks, Showcase, UseCases } from "../components/HowItWorks";
import { Navbar } from "../components/Navbar";
import { githubReleases, githubRepo } from "../content/site";
import { fetchLatestRelease } from "../lib/github";

export function Home() {
  const [cta, setCta] = useState({ href: githubRepo, label: "Get the beta" });

  useEffect(() => {
    void fetchLatestRelease().then((release) => {
      if (release) {
        setCta({ href: release.html_url, label: `Get ${release.tag_name}` });
        return;
      }
      setCta({ href: githubReleases, label: "Get the beta" });
    });
  }, []);

  return (
    <>
      <Navbar ctaHref={cta.href} ctaLabel={cta.label} />
      <main>
        <Hero ctaHref={cta.href} ctaLabel={cta.label} githubHref={githubRepo} />
        <Idea />
        <TrackpadSection />
        <GestureDemo />
        <LandscapeDemo />
        <PresentationDemo />
        <KeyboardDemo />
        <DeckDemo />
        <LocalFirst />
        <ReliabilityDemo />
        <HowItWorks />
        <Showcase />
        <UseCases />
        <ComingSoon />
        <FAQ />
        <FinalCTA ctaHref={cta.href} ctaLabel={cta.label} />
      </main>
      <Footer />
    </>
  );
}
