import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// CABIN TEMPERATURE page: target temperature per cabin zone (18-30 °C).
/// The actual temperature moves toward the target as the packs respond.
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
          const SizedBox(height: 14),
          FapPanel(
            title: 'NOTE',
            child: Text(
              'Cabin zone temperature can be adjusted from the FAP between '
              '${FapConstants.minTemp.round()} °C and '
              '${FapConstants.maxTemp.round()} °C in '
              '${FapConstants.tempStep} °C steps. The flight crew sets the '
              'basic zone temperature from the cockpit.',
              style: FapText.label,
            ),
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
    final settling = (actual - target).abs() >= 0.05;
    return FapPanel(
      title: zone.label,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text('ACTUAL', style: FapText.label),
          Text(
            '${actual.toStringAsFixed(1)} °C',
            style: FapText.monoStyle(
              size: 54,
              color: FapColors.cyan,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            settling ? (actual < target ? 'WARMING' : 'COOLING') : 'STABLE',
            style: FapText.monoStyle(
              size: 13,
              color: settling ? FapColors.amber : FapColors.okGreen,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 26),
          Text('SELECTED', style: FapText.label),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FapButton(
                label: '-',
                icon: Icons.remove,
                width: 70,
                height: 56,
                enabled: target > FapConstants.minTemp,
                onTap: () => fap.adjustTemp(zone, -FapConstants.tempStep),
              ),
              Container(
                width: 160,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF050B11),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FapColors.activeGreen),
                ),
                child: Text(
                  '${target.toStringAsFixed(1)} °C',
                  style: FapText.monoStyle(
                    size: 26,
                    color: FapColors.activeGreen,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              FapButton(
                label: '+',
                icon: Icons.add,
                width: 70,
                height: 56,
                enabled: target < FapConstants.maxTemp,
                onTap: () => fap.adjustTemp(zone, FapConstants.tempStep),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _RangeBar(value: target),
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final f =
        (value - FapConstants.minTemp) /
        (FapConstants.maxTemp - FapConstants.minTemp);
    return SizedBox(
      width: 330,
      child: Column(
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
                      colors: [
                        Color(0xFF2E7DFF),
                        FapColors.okGreen,
                        FapColors.amber,
                        FapColors.red,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: c.maxWidth * f - 6,
                  top: -4,
                  child: Container(
                    width: 12,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
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
              Text(
                '${FapConstants.minTemp.round()}°',
                style: FapText.monoStyle(size: 11, color: FapColors.textDim),
              ),
              Text(
                '${FapConstants.maxTemp.round()}°',
                style: FapText.monoStyle(size: 11, color: FapColors.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
