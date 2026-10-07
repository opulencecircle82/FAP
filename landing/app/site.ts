export const BASE_PATH = "/FAP";

export const supabase = {
  url: "https://spaxgxlhfuasehumkglb.supabase.co",
  // Publishable key: the database only exposes RPC functions to it.
  key: "sb_publishable_j1RmQ4wKmspwz0URRLvdTQ_7_iYrvGi",
};

export const site = {
  /** Show the license-code text once the activation database is live. */
  licensing: false,
  version: "3.2",
  apkName: "AISAT_FAP_v3.2.apk",
  repoUrl: "https://github.com/opulencecircle82/FAP",
  pageUrl: "https://opulencecircle82.github.io/FAP/",
  get apkUrl() {
    return `${this.repoUrl}/releases/latest/download/${this.apkName}`;
  },
  get releasesUrl() {
    return `${this.repoUrl}/releases`;
  },
  simulatorPath: `${BASE_PATH}/simulator/#/fap`,
};

/** Prefix a public asset with the GitHub Pages base path. */
export const asset = (path: string) => `${BASE_PATH}${path}`;
