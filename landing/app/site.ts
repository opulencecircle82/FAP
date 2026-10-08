export const BASE_PATH = "/FAP";

export const supabase = {
  url: "https://spaxgxlhfuasehumkglb.supabase.co",
  // Publishable key: the database only exposes RPC functions to it.
  key: "sb_publishable_j1RmQ4wKmspwz0URRLvdTQ_7_iYrvGi",
};

export const site = {
  /** Show the license-code text once the activation database is live. */
  licensing: true,
  version: "3.5",
  apkName: "A320_FAP_v3.5.apk",
  repoUrl: "https://github.com/opulencecircle82/FAP",
  pageUrl: "https://opulencecircle82.github.io/FAP/",
  get apkUrl() {
    return `${this.repoUrl}/releases/latest/download/${this.apkName}`;
  },
  get releasesUrl() {
    return `${this.repoUrl}/releases`;
  },
  /** YouTube tutorial (school-free version). */
  tutorialId: "KAeq-nrS088",
  get tutorialUrl() {
    return `https://www.youtube.com/watch?v=${this.tutorialId}`;
  },
};

/** Prefix a public asset with the GitHub Pages base path. */
export const asset = (path: string) => `${BASE_PATH}${path}`;
