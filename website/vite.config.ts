import { copyFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

function spaFallback() {
  return {
    name: "kamihi-spa-fallback",
    closeBundle() {
      const dist = resolve(__dirname, "dist");
      const index = resolve(dist, "index.html");
      copyFileSync(index, resolve(dist, "404.html"));
      mkdirSync(resolve(dist, "privacy"), { recursive: true });
      copyFileSync(index, resolve(dist, "privacy/index.html"));
    },
  };
}

export default defineConfig({
  base: process.env.BASE_PATH || "/",
  plugins: [react(), spaFallback()],
  build: {
    assetsInlineLimit: 4096,
    cssCodeSplit: true,
  },
});
