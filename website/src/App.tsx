import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { Home } from "./pages/Home";
import { Privacy } from "./pages/Privacy";

export function App() {
  const basename = import.meta.env.BASE_URL.replace(/\/$/, "") || undefined;
  return (
    <BrowserRouter basename={basename}>
      <div className="site-bg" aria-hidden="true" />
      <a className="skip" href="#hero-title">
        Skip to content
      </a>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/privacy" element={<Privacy />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
