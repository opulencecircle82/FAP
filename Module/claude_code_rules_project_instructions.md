# PROJECT CONFIGURATION & CLAUDE CODE SYSTEM RULES
**Project:** Airbus A320 Flight Attendant Panel (FAP) Simulator & Landing Page  
**Institution:** AISAT Aviation College  
**Target Path:** `D project/ AISAAT project/a320 flight attendant panel`  
**Tech Stack:** Flutter (Android Tablet & Web), Dart, Provider / Riverpod State Management  
**Backend:** None (Pure offline state, local memory / SharedPreferences)

---

## 1. PROJECT OVERVIEW & ARCHITECTURE

You are developing a high-fidelity **Airbus A320 Classic CIDS Flight Attendant Panel (FAP)** touchscreen simulator designed for AISAT Flight Attendant and Cabin Crew trainees. 

The project consists of two core components inside a single Flutter codebase:
1. **A320 FAP Tablet Simulator:** 1:1 hardware and touchscreen replica matching the classic Airbus CIDS architecture.
2. **AISAT Mobile App Landing Page:** A professional web screen with direct APK download options for students without requiring an external database.

---

## 2. DESIGN & VISUAL SYSTEM (EXACT A320 SPECIFICATIONS)

### Color Palette & Aesthetics
* **Screen Background:** `#13212E` (Deep Airbus Dark Blue)
* **Status Bar Header:** `#09131C`
* **Container Panels:** `#1A2C3D` (Slate Aviation Blue)
* **Active Selected Buttons:** `#00FF44` / `#00FF00` (Electric Bright Green with Black bold text)
* **Inactive / Unselected Buttons:** `#2C4257` (Beveled Slate Blue with White bold text)
* **Warning / Emergency:** `#FF2D2D` (Red), `#FFD700` (Gold / Amber)
* **Status Accents:** `#00E5FF` (Cyan)
* **Bezel / Hardware Frame:** `#C2C8CF` to `#8C95A0` Metallic Gradient

### Typography
* **Primary Sans:** Inter / Roboto
* **Digital Status Display:** JetBrains Mono or Courier New (Monospaced)
* **Header Titles:** Bold Uppercase Sans-Serif tracking wide

---

## 3. SCREEN LAYOUT & BUTTON FUNCTIONALITY MATRIX

### A. Screen Header & Status Bar
* **Left:** `FAP 1` system badge.
* **Status Message Banner:** Flashing Cyan text: *"Please check door/slide status prior departure"*.
* **Right:** Cabin Temperature (`22°C`) and Real-time UTC Clock (`HH:mm:ss`).
* **Title Bar:** Centered bold label: `CABIN LIGHTING`.

---

### B. Cabin Lighting Screen (Primary Screen)

#### 1. Center Aircraft Fuselage Diagram (`CustomPainter` or `SvgPicture`)
* Top-down vertical schematic of an **Airbus A320** in gold/yellow (`#FFD700`).
* Divided visually into **FWD** (Forward Cabin), **MID** (Overwing / Main Cabin), and **AFT** (Rear Cabin).
* **Dynamic Highlight:** Changing lighting modes must dynamically update the color fill intensity of the corresponding zone on the fuselage graphic.

#### 2. General Illumination Panel (Top Right)
Must contain 6 master buttons:
| Button Label | Action / Function |
| :--- | :--- |
| **100% BRT** | Sets master lighting across all zones to 100% maximum brightness. Highlighted Green when active. |
| **DIM 1** | Sets master lighting to 50% brightness (Boarding / Meal service mode). |
| **DIM 2** | Sets master lighting to 10% brightness (Rest mode). |
| **NIGHT** | Activates blue night-lighting mode across cabin zones. |
| **OFF** | Cuts off all primary overhead cabin illumination. |
| **MAIN ON / OFF** | Master power toggle for the CIDS general lighting system. |

#### 3. Zone Specific Lighting Controls
* **FWD CABIN Block:** `BRT 1`, `DIM 1`, `DIM 2` buttons.
* **AFT CABIN Block:** `BRT 1`, `DIM 1`, `DIM 2` buttons.
* **WINDOW LIGHTS Block:** `SELECT` toggle and `BRT` switch.
* **READING LIGHTS Block:** `ALL` (Passenger reading lamps), `FLT` (Flight deck override), `ATT` (Attendant station lamps).

---

### C. Bottom Touch Navigation Bar (Sub-Screen Tabs)
A horizontal row of capacitive-style touch buttons at the base of the touchscreen canvas:
1. **Audio:** Switches view to PRAM (Pre-Recorded Announcements) and PA Gain controls.
2. **Light:** Switches view to Cabin Lighting sub-screen (Default).
3. **Doors/Slides:** Displays door states (L1, R1, Overwing 1/2, L2, R2) and Evacuation Slide arming status.
4. **Evac:** Opens emergency evacuation signal controls.
5. **Water/Waste:** Displays Potable Water (200L) and Waste Water (170L) gauge percentages.
6. **Smoke Reset:** Resets lavatory smoke detector alerts.
7. **System Info:** Displays CIDS computer health and maintenance status.

---

### D. Physical Hardware Bezel Frame (Membrane Keys at Bottom)
Below the touchscreen display frame, render the tactile physical membrane key strip:
* **EMER Switch:** Red covered emergency signal button. Triggers cabin chime siren and evac alert.
* **CMD RESET:** Resets passenger call buttons and attendant chimes.
* **CABIN LIGHTS:** Quick physical shortcut back to the main lighting subscreen.
* **PA CALL:** Triggers attendant interphone chime chime synthesizer.
* **HANDSET Jack:** Graphic representation of the interphone coil cord port.

---

## 4. SUBSCREEN DETAILS

### 1. Doors & Evac Slides Screen
* **Status Items:**
  * Passenger Door L1 (Forward Left) -> `CLOSED / ARMED`
  * Service Door R1 (Forward Right) -> `CLOSED / ARMED`
  * Overwing Emergency Exits (L/R) -> `LOCKED / ARMED`
  * AFT Doors L2 / R2 -> `CLOSED / ARMED`
* **Slide Override Controls:** Interactive disarm test buttons for trainee drills.

### 2. Audio & PRAM Screen
* **PRAM Announcements:**
  * Boarding Music
  * Safety Demonstration
  * Fasten Seatbelts Warning
  * Turbulence Alert
  * Descent Preparation
* **PA Volume Sliders:** Interactive sliders for Cabin PA Gain and Boarding Music level.
* **Audio Synthesizer:** Play authentic Airbus high-low dual tone chime (600Hz -> 800Hz) on button press using `audioplayers` or Web Audio API.

### 3. Water & Waste Monitor Screen
* Vertical bar gauges for **Potable Water** (80% level) and **Waste Water** (25% level) with status indicators for Lavatories A, D, and E.

---

## 5. AISAT LANDING PAGE SPECIFICATIONS

A dedicated screen/view within the app displaying the **AISAT Aviation App Download Hub**:
* **Header & Branding:** Features the official **AISAT Aviation Logo** (Wings with Globe 'A' symbol in Cyan `#00A2E8` and Silver `#A8B2D1`).
* **Title:** *"AISAT Airbus A320 FAP Mobile & Tablet Simulator"*
* **Download Action:** Prominent button for downloading `AISAT_FAP_v2.4.apk`.
* **QR Code Display:** Rendered QR code for instant tablet camera scanning.
* **Feature Highlights:**
  * Offline Ready (No SQL/Database needed).
  * Authentic A320 CIDS Logic.
  * Flight Attendant Training Drills.

---

## 6. FLUTTER PROJECT DIRECTORY STRUCTURE

Enforce this folder layout when generating or modifying Flutter code:

```text
lib/
├── main.dart                   # Entry point, theme configuration, and main view router
├── models/
│   ├── fap_state.dart          # State model for lights, doors, audio, water level
│   └── pram_item.dart          # Announcement data model
├── providers/
│   └── fap_provider.dart       # Riverpod or Provider state notifier
├── screens/
│   ├── fap_simulator_screen.dart # Main FAP frame with physical bezel
│   ├── landing_page_screen.dart  # AISAT App Download Landing Page
│   └── subscreens/
│       ├── lighting_subscreen.dart
│       ├── doors_subscreen.dart
│       ├── audio_subscreen.dart
│       └── water_subscreen.dart
└── widgets/
    ├── aircraft_diagram.dart   # Interactive A320 fuselage CustomPainter/SVG
    ├── top_status_bar.dart     # Clock and top alerts
    ├── bottom_touch_nav.dart   # Touchscreen tab switcher
    ├── hardware_bezel_strip.dart # Physical membrane buttons frame
    └── aisat_logo.dart         # Vector SVG recreated AISAT logo
```

---

## 7. CLAUDE CODE WORKFLOW & EXPOSED COMMANDS

When working in the terminal via `claude`:
1. Use `flutter analyze` after creating widgets to verify zero Dart syntax errors.
2. Keep all state local (use `ChangeNotifier` or `StateNotifier`).
3. Ensure all responsive layouts use `LayoutBuilder` or `MediaQuery` configured for landscape tablet mode (aspect ratio 16:10 or 16:9).