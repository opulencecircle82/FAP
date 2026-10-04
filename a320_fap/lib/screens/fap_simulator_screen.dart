import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import '../widgets/blink.dart';
import '../widgets/bottom_touch_nav.dart';
import '../widgets/hardware_bezel_strip.dart';
import '../widgets/top_status_bar.dart';
import 'subscreens/audio_subscreen.dart';
import 'subscreens/cabin_status_subscreen.dart';
import 'subscreens/doors_subscreen.dart';
import 'subscreens/lighting_subscreen.dart';
import 'subscreens/smoke_subscreen.dart';
import 'subscreens/system_info_subscreen.dart';
import 'subscreens/temperature_subscreen.dart';
import 'subscreens/water_subscreen.dart';

/// The FAP unit: metallic bezel, 16:9 touchscreen and hard-key strip.
///
/// It is laid out once on a fixed design canvas and scaled to fit the
/// device, so the panel looks identical on every tablet and browser.
class FapSimulatorScreen extends StatelessWidget {
  const FapSimulatorScreen({super.key});

  static const route = '/fap';

  static const _screenSize = Size(1280, 720);
  static const _deviceSize = Size(1350, 940);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D13),
      body: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.fromSize(size: _deviceSize, child: const _Device()),
          ),
        ),
      ),
    );
  }
}

class _Device extends StatelessWidget {
  const _Device();

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
          const SizedBox(
            height: 22,
            child: Row(
              children: [
                _Screw(),
                Spacer(),
                Text(
                  'CIDS  FLIGHT ATTENDANT PANEL',
                  style: TextStyle(
                    color: Color(0xFF4B535C),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                Spacer(),
                _Screw(),
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
          if (fap.screenLocked) _LockOverlay(seconds: fap.lockRemaining),
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
    FapPage.systemInfo => const SystemInfoSubscreen(),
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

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: evac && blink ? FapColors.red : const Color(0xFF0F1B26),
        border: const Border(bottom: BorderSide(color: FapColors.panelBorder)),
      ),
      alignment: Alignment.center,
      child: evac
          ? content
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: content,
            ),
    );
  }
}

/// SCREEN 30 SEC LOCK: blocks touch input so the screen can be cleaned.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: const Color(0xD9000000),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: FapColors.amber,
                  size: 64,
                ),
                const SizedBox(height: 14),
                Text(
                  'SCREEN LOCKED',
                  style: FapText.title.copyWith(color: FapColors.amber),
                ),
                const SizedBox(height: 8),
                Text(
                  '$seconds s',
                  style: FapText.monoStyle(
                    size: 40,
                    color: FapColors.white,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Touchscreen disabled for cleaning',
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
