import Image from "next/image";
import QRCode from "qrcode";
import type { ReactNode } from "react";
import { asset, site } from "./site";

const features = [
  {
    title: "Offline Ready",
    body: "No SQL / database needed. Everything runs on the tablet, even with no internet in the classroom.",
    icon: "M3 3l18 18M8.5 8.5A5 5 0 0 0 6 18h11m3.4-1.6A4 4 0 0 0 18 10h-.5A6.5 6.5 0 0 0 10 5.2",
  },
  {
    title: "Authentic A320 CIDS Logic",
    body: "BRT / DIM 1 / DIM 2 lighting, slide arming, EVAC CMD and RESET, SMOKE RESET and real Airbus chimes.",
    icon: "M9 3v2m6-2v2M9 19v2m6-2v2M3 9h2m-2 6h2m14-6h2m-2 6h2M7 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zm3 5h4v4h-4z",
  },
  {
    title: "Flight Attendant Training Drills",
    body: "Arm / disarm and cross-check, lavatory smoke, evacuation, PRAM announcements and CIDS fault scenarios.",
    icon: "M12 4 2 9l10 5 10-5-10-5zm-6 7.5V16c0 1.7 2.7 3 6 3s6-1.3 6-3v-4.5",
  },
];

const pages = [
  ["STATUS", "Cabin overview of every system at a glance."],
  ["AUDIO", "4 boarding music channels, PRAM with MEMO / PLAY ALL, chimes."],
  ["LIGHTS", "BRT 100% · DIM 1 50% · DIM 2 10% per cabin zone."],
  ["DOORS / SLIDES", "8 exits. Open an armed door and the slide deploys."],
  ["TEMP", "FWD / AFT zones: ±2.5 °C fine adjustment of the cockpit setting."],
  ["WATER / WASTE", "200 L potable water, 170 L waste, lavatory status."],
  ["SMOKE", "LAV A / D / E detectors, SMOKE RESET, auto-clear when smoke is gone."],
  ["SEAT SETTING", "Inhibit call buttons or reading lights per seat, passenger calls."],
  ["SYSTEM INFO", "CIDS directors, CAPT / CAPT & PURS selector, fault drills."],
  ["CABIN PROG", "Move cabin zones between classes and save to the CAM."],
  ["LAYOUT SELECT", "Load 1-, 2- or 3-class CAM layouts."],
  ["LEVEL ADJUST", "Announcement and chime levels per zone, -6 to +6 dB."],
  ["SW LOAD / FAP SET-UP", "Software loading, brightness, loudspeaker, key click."],
];

const hardKeys = [
  ["EVAC CMD", "red"],
  ["EVAC RESET", "red"],
  ["EMER", "amber"],
  ["PED POWER", "green"],
  ["LIGHTS MAIN", "green"],
  ["LAV MAINT", "green"],
  ["SCREEN LOCK", "amber"],
  ["SMOKE RESET", "red"],
  ["FAP RESET", "amber"],
  ["PAX SYS", "green"],
] as const;

const shots = [
  ["doors.png", "Slide deployed after opening an armed door"],
  ["smoke.png", "Lavatory smoke alert with crew actions"],
  ["audio.png", "PRAM announcements and cabin chimes"],
  ["evac.png", "Evacuation command active"],
];

const steps = [
  "Scan the QR code with the tablet camera, or tap Download APK.",
  'Allow "Install unknown apps" for your browser when Android asks.',
  "Open AISAT FAP and hold the tablet in landscape.",
];

export default async function Home() {
  const qrSvg = await QRCode.toString(site.apkUrl, {
    type: "svg",
    margin: 0,
    color: { dark: "#0a1520", light: "#ffffff" },
  });

  return (
    <div className="radar">
      <header className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-5 sm:px-8">
        <Logo size={40} />
        <span className="text-sm font-extrabold tracking-[0.25em]">
          AISAT AVIATION
        </span>
        <nav className="ml-auto hidden items-center gap-7 text-sm text-silver md:flex">
          <a href="#features" className="hover:text-white">Features</a>
          <a href="#panel" className="hover:text-white">The Panel</a>
          <a href="#download" className="hover:text-white">Download</a>
        </nav>
        <a
          href={site.repoUrl}
          className="ml-auto rounded-full border border-cyan/50 px-3 py-1 font-mono text-xs font-bold text-cyan hover:bg-cyan/10 md:ml-6"
        >
          v{site.version}
        </a>
      </header>

      <main>
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-12 px-4 pt-10 pb-20 sm:px-8 lg:grid-cols-[1fr_1.15fr] lg:pt-16">
          <div className="text-center lg:text-left">
            <div className="flex justify-center lg:justify-start">
              <Logo size={120} glow />
            </div>
            <p className="mt-8 font-mono text-xs font-bold tracking-[0.3em] text-cyan">
              AIRBUS A320 · CIDS · FAP
            </p>
            <h1 className="mt-3 text-4xl leading-[1.1] font-extrabold sm:text-5xl">
              AISAT Airbus A320 FAP Mobile &amp; Tablet Simulator
            </h1>
            <p className="mt-5 text-lg leading-relaxed text-silver">
              Train on a full replica of the Airbus A320 Flight Attendant
              Panel: cabin lighting, doors and slides, PRAM announcements,
              water/waste, lavatory smoke and evacuation signalling.
            </p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row lg:justify-start">
              <DownloadButton />
              <a
                href={site.simulatorPath}
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-silver/60 px-6 py-4 text-sm font-extrabold tracking-wider hover:border-white hover:bg-white/5"
              >
                <Icon d="M8 5v14l11-7z" />
                TRY WEB SIMULATOR
              </a>
            </div>
            <p className="mt-4 text-xs text-silver/70">
              Android 7.0+ · Free · Landscape tablet recommended
            </p>
          </div>

          <ScreenFrame
            src="lights.png"
            alt="FAP cabin lighting page with A320 fuselage diagram"
            priority
          />
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <div className="grid gap-5 md:grid-cols-3">
            {features.map((f) => (
              <div
                key={f.title}
                className="rounded-2xl border border-line bg-panel/70 p-6"
              >
                <Icon d={f.icon} className="size-8 text-cyan" />
                <h3 className="mt-4 text-lg font-extrabold">{f.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-silver">
                  {f.body}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* The panel */}
        <section id="panel" className="border-y border-line bg-panel/40 py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-8">
            <SectionTitle
              kicker="THE PANEL"
              title="Every page of the classic CIDS FAP"
              body="Follows the real A320: grey keys are available, green is selected, amber is caution and red is alarm. Dashed TRAINER boxes let the instructor simulate what happens away from the panel."
            />
            <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {pages.map(([name, desc]) => (
                <div
                  key={name}
                  className="rounded-xl border border-line bg-ink/60 p-4"
                >
                  <div className="font-mono text-sm font-bold text-fap-green">
                    {name}
                  </div>
                  <p className="mt-1.5 text-sm text-silver">{desc}</p>
                </div>
              ))}
            </div>

            <div className="mt-10 rounded-2xl bg-gradient-to-b from-[#c2c8cf] to-[#8c95a0] p-5 text-[#1b232b]">
              <div className="mb-3 text-center text-[11px] font-extrabold tracking-[0.3em] text-[#4b535c]">
                HARD KEYS
              </div>
              <div className="grid grid-cols-5 gap-3 sm:grid-cols-10">
                {hardKeys.map(([label, led]) => (
                  <div key={label} className="flex flex-col items-center gap-1.5">
                    <span
                      className={`h-1 w-8 rounded ${
                        led === "red"
                          ? "bg-fap-red shadow-[0_0_8px] shadow-fap-red"
                          : led === "amber"
                            ? "bg-fap-amber shadow-[0_0_8px] shadow-fap-amber"
                            : "bg-fap-green shadow-[0_0_8px] shadow-fap-green"
                      }`}
                    />
                    <span
                      className={`h-9 w-full max-w-16 rounded-md border border-black/60 shadow-[0_3px_3px_rgb(0_0_0/0.5)] ${
                        label === "EVAC CMD"
                          ? "bg-gradient-to-b from-[#e53935] to-[#8e1010]"
                          : "bg-gradient-to-b from-[#4f5861] to-[#2b3138]"
                      }`}
                    />
                    <span className="text-center text-[10px] leading-tight font-extrabold">
                      {label}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-10 grid gap-5 sm:grid-cols-2">
              {shots.map(([src, caption]) => (
                <figure key={src}>
                  <ScreenFrame src={src} alt={caption} />
                  <figcaption className="mt-3 text-center text-sm text-silver">
                    {caption}
                  </figcaption>
                </figure>
              ))}
            </div>
          </div>
        </section>

        {/* Download */}
        <section id="download" className="mx-auto max-w-6xl scroll-mt-8 px-4 py-20 sm:px-8">
          <div className="grid items-center gap-10 rounded-3xl border border-cyan/30 bg-panel/80 p-6 shadow-[0_0_60px_rgb(0_162_232/0.12)] sm:p-10 md:grid-cols-[auto_1fr]">
            <div className="mx-auto">
              <div
                className="size-52 rounded-2xl bg-white p-4 [&>svg]:size-full"
                role="img"
                aria-label={`QR code linking to ${site.apkName}`}
                dangerouslySetInnerHTML={{ __html: qrSvg }}
              />
              <p className="mt-3 text-center font-mono text-sm font-bold text-cyan">
                {site.apkName}
              </p>
            </div>
            <div>
              <SectionTitle
                kicker="DOWNLOAD"
                title="Scan to install on your tablet"
              />
              <ol className="mt-6 space-y-3">
                {steps.map((s, i) => (
                  <li key={s} className="flex gap-3 text-silver">
                    <span className="grid size-6 shrink-0 place-items-center rounded-full bg-cyan text-xs font-extrabold text-black">
                      {i + 1}
                    </span>
                    {s}
                  </li>
                ))}
              </ol>
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <DownloadButton />
                <a
                  href={site.releasesUrl}
                  className="inline-flex items-center justify-center gap-2 rounded-xl px-6 py-4 text-sm font-bold text-silver hover:text-white"
                >
                  All releases on GitHub →
                </a>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-line px-4 py-8 text-center text-xs text-[#5e7184]">
        For AISAT Aviation College cabin crew training only. Not for
        operational use. Always follow your airline cabin crew manual.
      </footer>
    </div>
  );
}

function Logo({ size, glow = false }: { size: number; glow?: boolean }) {
  return (
    <Image
      src={asset("/aisat-logo.png")}
      alt="AISAT Aviation"
      width={size}
      height={size}
      priority={glow}
      className={`rounded-full border-2 border-cyan/50 ${
        glow ? "shadow-[0_0_40px_rgb(0_162_232/0.45)]" : ""
      }`}
    />
  );
}

function DownloadButton() {
  return (
    <a
      href={site.apkUrl}
      className="inline-flex items-center justify-center gap-2 rounded-xl bg-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
    >
      <Icon d="M12 3v12m0 0-5-5m5 5 5-5M5 21h14" />
      DOWNLOAD APK
    </a>
  );
}

function ScreenFrame({
  src,
  alt,
  priority = false,
}: {
  src: string;
  alt: string;
  priority?: boolean;
}) {
  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-[#070d13] shadow-[0_20px_60px_rgb(0_0_0/0.6)]">
      <Image
        src={asset(`/screens/${src}`)}
        alt={alt}
        width={1600}
        height={1000}
        priority={priority}
        className="h-auto w-full"
      />
    </div>
  );
}

function SectionTitle({
  kicker,
  title,
  body,
}: {
  kicker: string;
  title: string;
  body?: ReactNode;
}) {
  return (
    <div>
      <p className="font-mono text-xs font-bold tracking-[0.3em] text-cyan">
        {kicker}
      </p>
      <h2 className="mt-2 text-3xl font-extrabold">{title}</h2>
      {body && <p className="mt-3 max-w-3xl text-silver">{body}</p>}
    </div>
  );
}

function Icon({ d, className = "size-5" }: { d: string; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden
    >
      <path d={d} />
    </svg>
  );
}
