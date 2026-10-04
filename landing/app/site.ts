export const BASE_PATH = "/FAP";

export const site = {
  version: "2.4",
  apkName: "AISAT_FAP_v2.4.apk",
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
