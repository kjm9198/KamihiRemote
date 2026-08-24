import { Link } from "react-router-dom";
import { Footer } from "../components/FAQ";
import { Navbar } from "../components/Navbar";
import { githubRepo, product } from "../content/site";

export function Privacy() {
  return (
    <>
      <Navbar ctaHref={githubRepo} ctaLabel="View on GitHub" />
      <main className="wrap privacy">
        <p className="eyebrow">Privacy</p>
        <h1 className="display" style={{ fontSize: "clamp(40px, 7vw, 72px)" }}>
          What Kamihi Remote actually stores.
        </h1>
        <p className="lede">
          This page describes the current {product.version} apps. It is not a legal claim about a future cloud product.
        </p>

        <h2>Local network only</h2>
        <p>
          Core control is designed to talk directly between your iPhone and Mac on the local network. There is no Kamihi cloud account, and the apps do not include analytics or crash-reporting SDKs.
        </p>

        <h2>On-device settings</h2>
        <p>Each device may keep, in local storage:</p>
        <ul>
          <li>the six-digit pairing code</li>
          <li>manual host address and port, if you typed them</li>
          <li>trackpad, gesture, haptic and presentation preferences</li>
          <li>the Remote Deck layout</li>
          <li>a local device identifier and paired-host list used for reconnect</li>
        </ul>

        <h2>What travels on the network</h2>
        <p>
          Pointer motion, clicks, scrolls, keys, typed text, media commands and presentation actions are sent to the Mac you paired with so they can be performed there. Typed text is not uploaded to Kamihi. The iPhone also shows local connection quality (round-trip time) measured between the two devices.
        </p>

        <h2>Permissions</h2>
        <p>
          The iPhone asks to use the local network so it can find and talk to the Mac. The Mac host asks for Accessibility permission so it can move the cursor and type. Motion permission text exists for a future Air Mouse; that feature is not shipping yet.
        </p>

        <h2>What we do not do today</h2>
        <p>
          We do not operate a Kamihi telemetry service in these apps. We do not require an account for core control. We do not route cursor traffic through a Kamihi server.
        </p>

        <p>
          <Link to="/">Back to Kamihi Remote</Link>
        </p>
      </main>
      <Footer />
    </>
  );
}
