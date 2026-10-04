# AISAT A320 FAP Simulator (Flutter)

Airbus A320 CIDS Flight Attendant Panel trainer for Android tablets and the web.

## Pages
STATUS · AUDIO (PRAM) · LIGHTS · DOORS/SLIDES · TEMP · WATER/WASTE · SMOKE · SYSTEM INFO

Hard keys: EVAC CMD (guarded), EVAC RESET, EMER, LIGHTS MAIN ON/OFF,
LAV MAINT, SCREEN 30 SEC LOCK, SMOKE RESET, PAX SYS.

Controls inside dashed **TRAINER** boxes simulate actions outside the FAP,
such as the door arming lever, smoke in a lavatory, or a CIDS fault.

## Tests
`flutter test` runs the A320 logic tests. It also renders every page into
`test/goldens/` (to refresh those images, run `flutter test --update-goldens`).

The steps for building and publishing are in the README at the repository root.
