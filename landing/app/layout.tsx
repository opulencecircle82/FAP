import type { Metadata, Viewport } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { asset, site } from "./site";

const inter = Inter({ variable: "--font-inter", subsets: ["latin"] });
const jetbrains = JetBrains_Mono({
  variable: "--font-jetbrains",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(site.pageUrl),
  title: "AISAT A320 FAP Simulator",
  description:
    "Airbus A320 CIDS Flight Attendant Panel simulator for AISAT Aviation College cabin crew trainees. Free Android tablet app, works offline.",
  openGraph: {
    title: "AISAT Airbus A320 FAP Mobile & Tablet Simulator",
    description:
      "Train on a full replica of the A320 Flight Attendant Panel. Download the Android app.",
    images: [asset("/screens/lights.png")],
  },
};

export const viewport: Viewport = {
  themeColor: "#0a1520",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${jetbrains.variable} antialiased`}
    >
      <body className="min-h-screen font-sans">{children}</body>
    </html>
  );
}
