import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/aircraft_diagram.dart';
import '../../widgets/demo_gate.dart';
import '../../widgets/fap_button.dart';

/// CABIN LIGHTING page: BRT / DIM 1 / DIM 2 for the entry areas and for
/// each passenger class of the active CAM layout, general (all zones),
/// MAIN ON/OFF, window (WDO) and aisle lights, and reading lights
/// (R/L SET / R/L RESET). Pressing a selected level again switches the zone
/// off. EMER and LAV MAINT are hard keys.
class LightingSubscreen extends StatelessWidget {
  const LightingSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final classZones = fap.activeZones
        .where((z) => z != LightZone.fwdEntry && z != LightZone.aftEntry)
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ZonePanel(LightZone.fwdEntry),
                Spacer(),
                _LegendPanel(),
                Spacer(),
                _ZonePanel(LightZone.aftEntry),
              ],
            ),
          ),
          const SizedBox(width: 24),
          const SizedBox(
            width: 170,
            child: AircraftDiagram(mode: DiagramMode.lighting),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 330,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _GeneralPanel(),
                for (final z in classZones) ...[
                  const SizedBox(height: 12),
                  _ZonePanel(z),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CabinLightsPanel(),
                SizedBox(height: 14),
                _ReadingPanel(),
                Spacer(),
                _HardKeyStatusPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _levels = [LightLevel.bright, LightLevel.dim1, LightLevel.dim2];

class _ZonePanel extends StatelessWidget {
  const _ZonePanel(this.zone);
  final LightZone zone;

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final level = fap.lightLevel(zone);
    return FapPanel(
      title: zone.label,
      trailing: StatusTag(
        level == LightLevel.off ? 'OFF' : '${level.percent}%',
        level == LightLevel.off ? FapColors.textDim : FapColors.gold,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final l in _levels)
            FapButton(
              label: l.label,
              active: level == l,
              onTap: () => fap.setZoneLight(zone, l),
            ),
        ],
      ),
    );
  }
}

class _GeneralPanel extends StatelessWidget {
  const _GeneralPanel();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final general = fap.generalLevel;
    return FapPanel(
      title: 'GENERAL  -  ALL CABIN ZONES',
      titleColor: FapColors.cyan,
      trailing: StatusTag(
        fap.mainLightsOn ? 'MAIN ON' : 'MAIN OFF',
        fap.mainLightsOn ? FapColors.okGreen : FapColors.textDim,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final l in _levels)
            FapButton(
              label: l.label,
              active: general == l,
              onTap: () => fap.setGeneralLight(l),
            ),
        ],
      ),
    );
  }
}

class _CabinLightsPanel extends StatelessWidget {
  const _CabinLightsPanel();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return FapPanel(
      title: 'MAIN  /  WINDOW  /  AISLE',
      child: Row(
        children: [
          // The one lighting function of the demo version.
          DemoAllowed(
            child: FapButton(
              label: 'MAIN\nON/OFF',
              width: 96,
              fontSize: 12,
              active: fap.mainLightsOn,
              onTap: fap.toggleMainLights,
            ),
          ),
          const SizedBox(width: 10),
          FapButton(
            label: 'WDO',
            width: 96,
            active: fap.windowLights,
            onTap: fap.toggleWindowLights,
          ),
          const SizedBox(width: 10),
          FapButton(
            label: 'AISLE',
            width: 96,
            active: fap.aisleLights,
            onTap: fap.toggleAisleLights,
          ),
        ],
      ),
    );
  }
}

class _ReadingPanel extends StatelessWidget {
  const _ReadingPanel();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return FapPanel(
      title: 'READING LIGHTS',
      trailing: StatusTag(
        fap.readingAll
            ? (fap.readingInhibitedCount > 0
                  ? 'ON  (${fap.readingInhibitedCount} INHIB)'
                  : 'ON')
            : 'OFF',
        fap.readingAll ? FapColors.okGreen : FapColors.textDim,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FapButton(
                label: 'R/L\nSET',
                width: 96,
                fontSize: 12,
                active: fap.readingAll,
                onTap: () => fap.readingLightsSet(true),
              ),
              const SizedBox(width: 10),
              FapButton(
                label: 'R/L\nRESET',
                width: 96,
                fontSize: 12,
                onTap: () => fap.readingLightsSet(false),
              ),
              const SizedBox(width: 10),
              FapButton(
                label: 'ATTND',
                width: 96,
                active: fap.attWorkLights,
                onTap: fap.toggleAttWorkLights,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'R/L SET: all passenger reading lights on. R/L RESET: all off. '
            'ATTND: attendant work lights.',
            style: FapText.label,
          ),
        ],
      ),
    );
  }
}

/// Read-out of the lighting-related hard keys below the screen.
class _HardKeyStatusPanel extends StatelessWidget {
  const _HardKeyStatusPanel();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    Widget row(String name, bool on, String hint, Color onColor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: StatusTag(
              on ? 'ON' : 'OFF',
              on ? onColor : FapColors.textDim,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$name  ', style: FapText.body),
                  TextSpan(text: hint, style: FapText.label),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return FapPanel(
      title: 'HARD KEY STATUS',
      child: Column(
        children: [
          row(
            'MAIN',
            fap.mainLightsOn,
            'LIGHTS MAIN ON/OFF key',
            FapColors.okGreen,
          ),
          row(
            'LAV',
            fap.lavMaint,
            'LAV MAINT - full bright',
            FapColors.okGreen,
          ),
          row(
            'EMER',
            fap.emerLights,
            'EMER - emergency lighting',
            FapColors.amber,
          ),
        ],
      ),
    );
  }
}

class _LegendPanel extends StatelessWidget {
  const _LegendPanel();

  @override
  Widget build(BuildContext context) {
    Widget item(String level, String use) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              level,
              style: FapText.monoStyle(
                size: 12,
                color: FapColors.gold,
                weight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(use, style: FapText.label)),
        ],
      ),
    );
    return FapPanel(
      title: 'LIGHT LEVELS',
      child: Column(
        children: [
          item('BRT 100%', 'Boarding, disembarking'),
          item('DIM 1 50%', 'Meal service'),
          item('DIM 2 10%', 'Rest, night take-off & landing'),
        ],
      ),
    );
  }
}
