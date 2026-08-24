export const githubRepo = "https://github.com/kjm9198/KamihiRemote";
export const githubReleases = `${githubRepo}/releases`;
export const githubNewIssue = `${githubRepo}/issues/new`;

export const product = {
  name: "Kamihi Remote",
  studio: "Kamihi Studio",
  version: "0.2.0",
  ios: "26",
  macos: "26",
  year: 2026,
};

export const meta = {
  title: "Kamihi Remote — Turn your iPhone into a Mac trackpad & remote",
  description:
    "Control your Mac from your iPhone with a trackpad, Mac-like gestures, presentation controls, keyboard, media remote and shortcut deck. Local Wi-Fi. No account.",
};

export function asset(path: string): string {
  const base = import.meta.env.BASE_URL;
  return `${base}${path.replace(/^\//, "")}`;
}

export function withBase(path: string): string {
  if (path.startsWith("http")) return path;
  if (path.startsWith("#")) return path;
  const trimmed = path.startsWith("/") ? path : `/${path}`;
  if (trimmed === "/") return import.meta.env.BASE_URL;
  const base = import.meta.env.BASE_URL.replace(/\/$/, "");
  return `${base}${trimmed}`;
}
