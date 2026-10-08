import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import '../widgets/blink.dart';
import '../widgets/bottom_touch_nav.dart';
import '../widgets/demo_gate.dart';
import '../widgets/fap_button.dart';
import '../widgets/hardware_bezel_strip.dart';
import '../widgets/top_status_bar.dart';
import 'subscreens/audio_subscreen.dart';
import 'subscreens/cabin_prog_subscreen.dart';
import 'subscreens/cabin_status_subscreen.dart';
import 'subscreens/doors_subscreen.dart';
import 'subscreens/fap_setup_subscreen.dart';
import 'subscreens/layout_subscreen.dart';
import 'subscreens/level_subscreen.dart';
import 'subscreens/lighting_subscreen.dart';
import 'subscreens/seat_subscreen.dart';
import 'subscreens/smoke_subscreen.dart';
import 'subscreens/sw_load_subscreen.dart';
import 'subscreens/system_info_subscreen.dart';
import 'subscreens/temperature_subscreen.dart';
import 'subscreens/water_subscreen.dart';
import 'settings_dialog.dart';
import 'unlock_screen.dart';

/// The FAP unit: metallic bezel, 16:9 touchscreen and hard-key strip.
///
/// It is laid out once on a fixed design canvas and scaled to fit the
/// device, so the panel looks identical on every tablet and browser.
class FapSimulatorScreen extends StatelessWidget {
  const FapSimulatorScreen({
    super.key,
    this.demo = false,
    this.onLicensed,
    this.onDeactivated,
  });

  static const route = '/fap';

  static const _screenSize = Size(1280, 720);
  static const _deviceSize = Size(1350, 952);

  /// Demo version: only the [DemoAllowed] controls work; touching anything
  /// else asks for the license code.
  final bool demo;
  final VoidCallback? onLicensed;

  /// Settings > Deactivate & Transfer locked this device.
  final VoidCallback? onDeactivated;

  @override
  Widget build(BuildContext context) {
    void askLicense() =>
        showLicenseDialog(context, onUnlocked: () => onLicensed?.call());
    return Scaffold(
      backgroundColor: const Color(0xFF070D13),
      body: SafeArea(
        child: _panel(
          askLicense,
          // Licensed only: the demo has its own ENTER LICENSE CODE button.
          demo
              ? null
              : () => showSettingsDialog(
                  context,
                  onDeactivated: () => onDeactivated?.call(),
                ),
        ),
      ),
    );
  }

  Widget _panel(VoidCallback askLicense, VoidCallback? onSettings) => Column(
    children: [
      if (demo) _DemoBar(onEnterCode: askLicense),
      Expanded(
        child: DemoGate(
          active: demo,
          onBlocked: askLicense,
          // Tight constraints so the panel scales UP on large screens
          // too, not only down on small ones.
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: _deviceSize,
                child: _Device(onSettings: onSettings),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _DemoBar extends StatelessWidget {
  const _DemoBar({required this.onEnterCode});
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF2A1F05),
      child: Row(
        children: [
          const Icon(Icons.lock_open, color: FapColors.amber, size: 20),
          const SizedBox(width: 8),
          const Text(
            'DEMO VERSION',
            style: TextStyle(
              color: FapColors.amber,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Only LIGHTS: MAIN ON/OFF and AUDIO: boarding music ON/OFF work.',
              overflow: TextOverflow.ellipsis,
              style: FapText.label,
            ),
          ),
          FilledButton(
            onPressed: onEnterCode,
            style: FilledButton.styleFrom(
              backgroundColor: FapColors.amber,
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'ENTER LICENSE CODE',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Device extends StatelessWidget {
  const _Device({this.onSettings});

  /// Simulator SETTINGS key in the top frame (license, transfer).
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FapColors.bezelLight,
            Color(0xFFA9B0B8),
            FapColors.bezelDark,
          ],
        ),
        border: Border.all(color: const Color(0xFF5F6770), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Row(children: [_Screw(), Spacer(), _Screw()]),
                const Text(
                  'CIDS  FLIGHT ATTENDANT PANEL',
                  style: TextStyle(
                    color: Color(0xFF4B535C),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                if (onSettings != null)
                  Positioned(
                    right: 22,
                    top: 2,
                    bottom: 2,
                    child: _SettingsKey(onTap: onSettings!),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF050608),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF3D444C), width: 1.5),
            ),
            child: SizedBox.fromSize(
              size: FapSimulatorScreen._screenSize,
              child: const _Touchscreen(),
            ),
          ),
          const SizedBox(height: 14),
          const Expanded(child: HardwareBezelStrip()),
        ],
      ),
    );
  }
}

/// Simulator settings key on the panel frame (not part of the real FAP).
class _SettingsKey extends StatelessWidget {
  const _SettingsKey({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Settings',
      child: Material(
        color: const Color(0xFF2B3640),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings, size: 18, color: FapColors.cyan),
                SizedBox(width: 6),
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Screw extends StatelessWidget {
  const _Screw();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFE2E6EA), Color(0xFF6E7781)],
        ),
      ),
    );
  }
}

class _Touchscreen extends StatelessWidget {
  const _Touchscreen();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: FapColors.screenBg,
              child: Column(
                children: [
                  const TopStatusBar(),
                  const _TitleBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      child: KeyedSubtree(
                        key: ValueKey(fap.page),
                        child: _pageFor(fap.page),
                      ),
                    ),
                  ),
                  const BottomTouchNav(),
                ],
              ),
            ),
          ),
          // FAP SET-UP brightness: dims the whole display.
          if (fap.brightness < 100)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: (100 - fap.brightness) / 100 * 0.8,
                  ),
                ),
              ),
            ),
          if (fap.configOpen) const _FapConfigPanel(),
          if (fap.swProgress != null) _SwLoadingOverlay(fap.swProgress!),
          if (fap.screenLocked) _LockOverlay(seconds: fap.lockRemaining),
          if (fap.fapRestarting) const _RestartOverlay(),
          if (fap.screenOff)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => fap.setScreenOff(false),
                child: const ColoredBox(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pageFor(FapPage p) => switch (p) {
    FapPage.cabinStatus => const CabinStatusSubscreen(),
    FapPage.audio => const AudioSubscreen(),
    FapPage.lights => const LightingSubscreen(),
    FapPage.doors => const DoorsSubscreen(),
    FapPage.temperature => const TemperatureSubscreen(),
    FapPage.water => const WaterSubscreen(),
    FapPage.smoke => const SmokeSubscreen(),
    FapPage.seat => const SeatSubscreen(),
    FapPage.systemInfo => const SystemInfoSubscreen(),
    FapPage.cabinProg => const CabinProgSubscreen(),
    FapPage.layout => const LayoutSubscreen(),
    FapPage.level => const LevelSubscreen(),
    FapPage.swLoad => const SwLoadSubscreen(),
    FapPage.fapSetup => const FapSetupSubscreen(),
  };
}

/// Page title. A transient notice temporarily replaces the title so it
/// never covers controls; an active EVAC takes priority over both.
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final blink = context.watch<Blink>().value;
    final evac = fap.evacActive;
    final notice = evac ? null : fap.notice;

    final Widget content;
    if (evac) {
      content = Text(
        'EVAC  -  PRESS EVAC RESET TO SILENCE',
        style: FapText.title.copyWith(
          color: blink ? FapColors.white : FapColors.red,
        ),
      );
    } else if (notice != null) {
      content = Container(
        key: ValueKey(notice.id),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF050B11),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: notice.color, width: 1.5),
        ),
        child: Text(
          notice.text,
          style: FapText.monoStyle(
            size: 15,
            color: notice.color,
            weight: FontWeight.w700,
          ),
        ),
      );
    } else {
      content = Text(
        fap.page.title,
        key: ValueKey(fap.page),
        style: FapText.title,
      );
    }

    Widget small(String label, VoidCallback onTap, {bool active = false}) =>
        FapButton(
          label: label,
          width: 116,
          height: 26,
          fontSize: 10.5,
          active: active,
          onTap: onTap,
        );

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: evac && blink ? FapColors.red : const Color(0xFF0F1B26),
        border: const Border(bottom: BorderSide(color: FapColors.panelBorder)),
      ),
      child: Row(
        children: [
          small('SCREEN OFF', () => fap.setScreenOff(true)),
          const SizedBox(width: 6),
          small('CABIN READY', fap.toggleCabinReady, active: fap.cabinReady),
          Expanded(
            child: Center(
              child: evac
                  ? content
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: content,
                    ),
            ),
          ),
          small('FAP CONFIG', fap.toggleConfig, active: fap.configOpen),
        ],
      ),
    );
  }
}

/// FAP-PC RESET: the panel computer restarts; cabin systems keep running.
class _RestartOverlay extends StatelessWidget {
  const _RestartOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: FapColors.cyan,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'FAP RESTARTING',
                  style: FapText.title.copyWith(color: FapColors.cyan),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cabin systems are not affected',
                  style: FapText.label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SCREEN 30 SEC LOCK (clean function): blocks touch input so the screen
/// can be cleaned.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final left = seconds / 30;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CLEAN FUNCTION',
                  style: FapText.title.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 4),
                const Text('SCREEN 30sec LOCK', style: FapText.title),
                const SizedBox(height: 40),
                Text(
                  'REMAINING TIME\nTO CLEAN THE\nTOUCHSCREEN',
                  textAlign: TextAlign.center,
                  style: FapText.title.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '$seconds SEC.',
                  style: FapText.title.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 460,
                  height: 46,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2C8CF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Container(
                    color: const Color(0xFFDDEFFF),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: left.clamp(0.0, 1.0),
                      child: Container(color: const Color(0xFF2B3A8C)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SW LOAD in progress: blocks the panel until the CIDS restarts.
class _SwLoadingOverlay extends StatelessWidget {
  const _SwLoadingOverlay(this.progress);
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: const Color(0xAA000000),
          child: Center(
            child: Container(
              width: 760,
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 44),
              decoration: BoxDecoration(
                color: const Color(0xFF2B3A8C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF5C6BC0), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'WAIT UNTIL SOFTWARE LOADING IS COMPLETED !',
                    textAlign: TextAlign.center,
                    style: FapText.title,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 480,
                    height: 46,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC2C8CF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Container(
                      color: const Color(0xFFDDEFFF),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(color: const Color(0xFF1A237E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'CIDS WILL RESTART AUTOMATICALLY AFTER\n'
                    'SOFTWARE LOADING PROCESS !',
                    textAlign: TextAlign.center,
                    style: FapText.title,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FAP CONFIG: simulator settings (temperature unit, mute).
class _FapConfigPanel extends StatelessWidget {
  const _FapConfigPanel();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return Positioned(
      right: 12,
      top: 80,
      width: 420,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FapColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FapColors.cyan, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0xAA000000), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('FAP CONFIG', style: FapText.title),
                  ),
                  FapButton(
                    label: '',
                    icon: Icons.close,
                    width: 44,
                    height: 36,
                    onTap: fap.toggleConfig,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('TEMP. UNIT', style: FapText.label),
              const SizedBox(height: 6),
              Row(
                children: [
                  FapButton(
                    label: 'CELSIUS',
                    width: 130,
                    active: !fap.tempFahrenheit,
                    onTap: () => fap.setTempUnit(false),
                  ),
                  const SizedBox(width: 10),
                  FapButton(
                    label: 'FAHRENHEIT',
                    width: 130,
                    active: fap.tempFahrenheit,
                    onTap: () => fap.setTempUnit(true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('MUTE ALL AUDIO', style: FapText.label),
              const SizedBox(height: 6),
              Row(
                children: [
                  FapButton(
                    label: 'MUTE',
                    width: 130,
                    active: fap.muteAll,
                    onTap: () => fap.setMuteAll(!fap.muteAll),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Simulator settings - not part of the aircraft FAP.',
                style: FapText.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
