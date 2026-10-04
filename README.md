# FAP — AISAT Airbus A320 Flight Attendant Panel Simulator

A training replica of the A320 CIDS Flight Attendant Panel, built for
AISAT Aviation College cabin crew trainees.

- **Landing page:** https://opulencecircle82.github.io/FAP/
- **Web simulator:** https://opulencecircle82.github.io/FAP/simulator/#/fap
- **Android APK:** [latest release](https://github.com/opulencecircle82/FAP/releases/latest)

| Folder | What it is |
| --- | --- |
| `a320_fap/` | Flutter app (Android tablet + web). It runs fully offline. |
| `landing/` | Next.js landing page (static export for GitHub Pages) |
| `Module/` | Original project brief, reference photo and AISAT logo |

## Release a new APK
```bash
cd a320_fap
flutter test
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk AISAT_FAP_vX.Y.apk
gh release create vX.Y.0 AISAT_FAP_vX.Y.apk --title "AISAT FAP vX.Y"
```
The download button and the QR codes always point to the newest release.
When the version number changes, update `apkName` in
`landing/app/site.ts` and `apkFileName` in `a320_fap/lib/config.dart`.

## Update the landing page
```bash
./deploy.sh
```
