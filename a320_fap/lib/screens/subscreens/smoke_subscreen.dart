import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/aircraft_diagram.dart';
import '../../widgets/fap_button.dart';

/// SMOKE DETECTION page: lavatory smoke detector status. The page pops up
/// automatically on a smoke alert. SMOKE RESET (hard key or this page)
/// silences the alert; the FAP keeps showing smoke while it is detected,
/// and the CIDS clears everything automatically once the smoke is gone.
class SmokeSubscreen extends StatelessWidget {
  const SmokeSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 170,
            child: AircraftDiagram(mode: DiagramMode.smoke),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in Lavatory.values) ...[
                  _LavCard(lav: l, fap: fap),
                  const SizedBox(height: 12),
                ],
                const Spacer(),
                _ResetHint(fap: fap),
              ],
            ),
          ),
          const SizedBox(width: 24),
          const Expanded(child: _ProcedurePanel()),
        ],
      ),
    );
  }
}

class _LavCard extends StatelessWidget {
  const _LavCard({required this.lav, required this.fap});
  final Lavatory lav;
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final s = fap.smoke(lav);
    final (Color color, String text, bool flash) = switch (s.alert) {
      SmokeAlert.alarm => (FapColors.red, 'SMOKE', true),
      SmokeAlert.reset => (FapColors.red, 'SMOKE  (RESET)', false),
      SmokeAlert.normal => (FapColors.okGreen, 'NORMAL', false),
    };

    return FapPanel(
      title: '${lav.label}  (${lav.location})',
      borderColor: s.alert == SmokeAlert.normal
          ? FapColors.panelBorder
          : color.withValues(alpha: 0.8),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusTag(
                text,
                color,
                flashing: flash,
                size: 15,
                filled: flash,
              ),
            ),
          ),
          const Spacer(),
          TrainerBox(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                FapButton(
                  label: 'SMOKE',
                  width: 100,
                  height: 36,
                  fontSize: 12,
                  enabled: !s.source,
                  onTap: () => fap.triggerSmoke(lav),
                ),
                const SizedBox(width: 8),
                FapButton(
                  label: 'EXTINGUISH',
                  width: 110,
                  height: 36,
                  fontSize: 12,
                  enabled: s.source,
                  onTap: () => fap.extinguishSmoke(lav),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetHint extends StatelessWidget {
  const _ResetHint({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (fap.smokeAlarm) {
      text = 'Press SMOKE RESET to silence the alert.';
      color = FapColors.red;
    } else if (fap.smokeMonitoring) {
      text =
          'Alert silenced. Smoke still detected - the indication stays '
          'until the smoke is gone.';
      color = FapColors.amber;
    } else {
      text = 'All lavatory smoke detectors normal.';
      color = FapColors.okGreen;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FapColors.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: FapText.monoStyle(
                size: 13,
                color: color,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FapButton(
            label: 'SMOKE RESET',
            width: 130,
            height: 46,
            fontSize: 12,
            tone: fap.smokeAlarm ? FapButtonTone.red : FapButtonTone.normal,
            flashing: fap.smokeAlarm,
            onTap: fap.smokeReset,
          ),
        ],
      ),
    );
  }
}

class _ProcedurePanel extends StatelessWidget {
  const _ProcedurePanel();

  static const _steps = [
    'Press SMOKE RESET to silence the aural alert.',
    'Go to the lavatory. Feel the door with the back of your hand before '
        'opening.',
    'Locate the source. If fire: get the nearest extinguisher and fight it.',
    'Inform the cockpit immediately (interphone).',
    'Keep the door closed after extinguishing; monitor for re-ignition.',
    'When no more smoke is detected, the CIDS clears all indications.',
  ];

  @override
  Widget build(BuildContext context) {
    return FapPanel(
      title: 'LAV SMOKE - CREW ACTIONS',
      titleColor: FapColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}.',
                      style: FapText.monoStyle(
                        size: 13,
                        color: FapColors.cyan,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: FapText.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Always follow your airline cabin crew manual.',
            style: FapText.label.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
