import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/aircraft_diagram.dart';
import '../../widgets/fap_button.dart';

/// CABIN LIGHTING page: per-zone BRT / DIM 1 / DIM 2, general (all zones),
/// window and reading lights. Pressing a selected level again switches the
/// zone off. LIGHTS MAIN ON/OFF, EMER and LAV MAINT are hard keys.
class LightingSubscreen extends StatelessWidget {
  const LightingSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SizedBox(
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
          SizedBox(width: 24),
          SizedBox(
            width: 170,
            child: AircraftDiagram(mode: DiagramMode.lighting),
          ),
          SizedBox(width: 24),
          SizedBox(
            width: 330,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GeneralPanel(),
                SizedBox(height: 18),
                _ZonePanel(LightZone.fwdCabin),
                Spacer(),
                _ZonePanel(LightZone.aftCabin),
              ],
            ),
          ),
          SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WindowPanel(),
                SizedBox(height: 18),
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

class _WindowPanel extends StatelessWidget {
  const _WindowPanel();

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return FapPanel(
      title: 'WINDOW',
      child: Row(
        children: [
          FapButton(
            label: 'ON',
            active: fap.windowLights,
            onTap: fap.toggleWindowLights,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              fap.windowLights ? 'Window lights ON' : 'Window lights OFF',
              style: FapText.label,
            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FapButton(
                label: 'ALL',
                active: fap.readingAll,
                onTap: fap.toggleReadingAll,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Passenger reading lights (all seats)',
                  style: FapText.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FapButton(
                label: 'ATTND',
                active: fap.attWorkLights,
                onTap: fap.toggleAttWorkLights,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Attendant work lights', style: FapText.label),
              ),
            ],
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
