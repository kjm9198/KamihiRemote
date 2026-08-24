export type GithubRelease = {
  tag_name: string;
  html_url: string;
  name: string | null;
  prerelease: boolean;
  draft: boolean;
};

export async function fetchLatestRelease(): Promise<GithubRelease | null> {
  try {
    const response = await fetch(
      "https://api.github.com/repos/kjm9198/KamihiRemote/releases/latest",
      { headers: { Accept: "application/vnd.github+json" } },
    );
    if (!response.ok) return null;
    const data = (await response.json()) as GithubRelease;
    if (data.draft) return null;
    return data;
  } catch {
    return null;
  }
}

