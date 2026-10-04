import type { NextConfig } from "next";

// Static export served by GitHub Pages at https://<user>.github.io/FAP/
const nextConfig: NextConfig = {
  output: "export",
  basePath: "/FAP",
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
