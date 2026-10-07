import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// CABIN TEMPERATURE page. The flight crew selects each zone temperature
/// in the cockpit (18-30 °C); the cabin crew can fine-adjust it from the
/// FAP by ±2.5 °C. The actual temperature follows as the packs respond.
class TemperatureSubscreen extends StatelessWidget {
  const TemperatureSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final z in TempZone.values) ...[
                  Expanded(
                    child: _ZoneCard(zone: z, fap: fap),
                  ),
                  if (z != TempZone.values.last) const SizedBox(width: 24),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TrainerBox(
            label: 'TRAINER  -  COCKPIT ZONE TEMPERATURE SELECTORS',
            child: Row(
              children: [
                for (final z in TempZone.values) ...[
                  Text(z.label, style: FapText.panelTitle),
                  const SizedBox(width: 12),
                  FapButton(
                    label: '-',
                    icon: Icons.remove,
                    width: 56,
                    height: 38,
                    enabled: fap.cockpitTemp(z) > FapConstants.minTemp,
                    onTap: () =>
                        fap.adjustCockpitTemp(z, -FapConstants.tempStep),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      fap.formatTemp(fap.cockpitTemp(z)),
                      textAlign: TextAlign.center,
                      style: FapText.monoStyle(
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FapButton(
                    label: '+',
                    icon: Icons.add,
                    width: 56,
                    height: 38,
                    enabled: fap.cockpitTemp(z) < FapConstants.maxTemp,
                    onTap: () =>
                        fap.adjustCockpitTemp(z, FapConstants.tempStep),
                  ),
                  const SizedBox(width: 40),
                ],
                const Expanded(
                  child: Text(
                    'Flight crew selection, 18-30 °C',
                    style: FapText.label,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: FapPanel(
                  title: 'NOTE',
                  child: Text(
                    'The flight crew selects each zone temperature in the '
                    'cockpit. From the FAP the cabin crew can fine-adjust each '
                    'zone by ±2.5 °C in 0.5 °C steps. For a bigger change, ask '
                    'the flight crew.',
                    style: FapText.label,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FapButton(
                label: 'RESET TO COCKPIT\nSELECTED TEMP',
                width: 230,
                height: 66,
                fontSize: 12,
                onTap: fap.resetTempToCockpit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.fap});
  final TempZone zone;
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final actual = fap.actualTemp(zone);
    final target = fap.targetTemp(zone);
    final trim = fap.fapTrim(zone);
    const limit = FapConstants.fapTempTrim;
    final settling = (actual - target).abs() >= 0.05;
    final sign = trim > 0 ? '+' : (trim < 0 ? '-' : '');
    final trimText = '$sign${trim.abs().toStringAsFixed(1)}';

    Widget readout(String label, String value, Color color) => Column(
      children: [
        Text(label, style: FapText.label.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: FapText.monoStyle(
            size: 17,
            color: color,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );

    return FapPanel(
      title: zone.label,
      child: Column(
        children: [
          const SizedBox(height: 4),
          const Text('ACTUAL', style: FapText.label),
          Text(
            fap.formatTemp(actual),
            style: FapText.monoStyle(
              size: 50,
              color: FapColors.cyan,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            settling ? (actual < target ? 'WARMING' : 'COOLING') : 'STABLE',
            style: FapText.monoStyle(
              size: 13,
              color: settling ? FapColors.amber : FapColors.okGreen,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              readout(
                'COCKPIT SEL',
                fap.formatTemp(fap.cockpitTemp(zone)),
                FapColors.white,
              ),
              readout('FAP ADJ', '$trimText°', FapColors.activeGreen),
              readout('TARGET', fap.formatTemp(target), FapColors.cyan),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FapButton(
                label: '-',
                icon: Icons.remove,
                width: 70,
                height: 52,
                enabled: trim > -limit,
                onTap: () => fap.adjustTemp(zone, -FapConstants.tempStep),
              ),
              const SizedBox(width: 16),
              _TrimBar(trim: trim),
              const SizedBox(width: 16),
              FapButton(
                label: '+',
                icon: Icons.add,
                width: 70,
                height: 52,
                enabled: trim < limit,
                onTap: () => fap.adjustTemp(zone, FapConstants.tempStep),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// -2.5 … +2.5 °C fine-adjustment indicator.
class _TrimBar extends StatelessWidget {
  const _TrimBar({required this.trim});
  final double trim;

  @override
  Widget build(BuildContext context) {
    const limit = FapConstants.fapTempTrim;
    final f = (trim + limit) / (2 * limit);
    final dim = FapText.monoStyle(size: 11, color: FapColors.textDim);
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, c) => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7DFF), Colors.white, FapColors.red],
                    ),
                  ),
                ),
                Positioned(
                  left: c.maxWidth / 2 - 1,
                  top: -3,
                  child: Container(width: 2, height: 16, color: Colors.black),
                ),
                Positioned(
                  left: c.maxWidth * f - 6,
                  top: -4,
                  child: Container(
                    width: 12,
                    height: 18,
                    decoration: BoxDecoration(
                      color: FapColors.activeGreen,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('-$limit', style: dim),
              Text('0', style: dim),
              Text('+$limit', style: dim),
            ],
          ),
        ],
      ),
    );
  }
}
