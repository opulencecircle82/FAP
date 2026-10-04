import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// WATER / WASTE page: potable water (200 L) and waste (170 L) quantities,
/// water quantity preselection and lavatory status.
class WaterSubscreen extends StatelessWidget {
  const WaterSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    final waterColor = fap.waterEmpty
        ? FapColors.red
        : (fap.waterLow ? FapColors.amber : FapColors.cyan);
    final wasteColor = fap.wasteFull
        ? FapColors.red
        : (fap.wasteHigh ? FapColors.amber : FapColors.okGreen);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: _Gauge(
              title: 'POTABLE WATER',
              pct: fap.waterPct,
              litres: fap.waterLitres,
              capacity: FapConstants.potableWaterLitres,
              color: waterColor,
              status: fap.waterEmpty
                  ? 'EMPTY'
                  : (fap.waterLow ? 'LOW' : 'NORMAL'),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 250,
            child: _Gauge(
              title: 'WASTE',
              pct: fap.wastePct,
              litres: fap.wasteLitres,
              capacity: FapConstants.wasteTankLitres,
              color: wasteColor,
              status: fap.wasteFull
                  ? 'TANK FULL'
                  : (fap.wasteHigh ? 'HIGH' : 'NORMAL'),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FapPanel(
                  title: 'WATER QUANTITY PRESELECTION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (final p in FapConstants.waterPreselect) ...[
                            FapButton(
                              label: '$p%',
                              width: 86,
                              active: fap.waterPreselect == p,
                              onTap: () => fap.setWaterPreselect(p),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tank is filled to the preselected level at the next '
                        'servicing (${(FapConstants.potableWaterLitres * fap.waterPreselect / 100).round()} L).',
                        style: FapText.label,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FapPanel(
                  title: 'LAVATORIES',
                  child: Row(
                    children: [
                      for (final l in Lavatory.values) ...[
                        Expanded(
                          child: _LavTile(lav: l, fap: fap),
                        ),
                        if (l != Lavatory.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                TrainerBox(
                  label: 'TRAINER  -  GROUND SERVICE / FLIGHT',
                  child: Row(
                    children: [
                      _trainer('USE WATER\n-10%', fap.consumeWater),
                      _trainer('REFILL\nWATER', fap.refillWater),
                      _trainer('ADD WASTE\n+10%', fap.addWaste),
                      _trainer('DRAIN\nWASTE', fap.drainWaste),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainer(String label, VoidCallback onTap) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FapButton(
        label: label,
        width: double.infinity,
        height: 46,
        fontSize: 12,
        onTap: onTap,
      ),
    ),
  );
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.title,
    required this.pct,
    required this.litres,
    required this.capacity,
    required this.color,
    required this.status,
  });

  final String title;
  final double pct;
  final double litres;
  final int capacity;
  final Color color;
  final String status;

  @override
  Widget build(BuildContext context) {
    return FapPanel(
      title: title,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: SizedBox(
        height: 470,
        child: Column(
          children: [
            Text(
              '${pct.round()}%',
              style: FapText.monoStyle(
                size: 34,
                color: color,
                weight: FontWeight.w700,
              ),
            ),
            Text(
              '${litres.round()} / $capacity L',
              style: FapText.monoStyle(size: 14, color: FapColors.textDim),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Scale
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final v in [100, 75, 50, 25, 0])
                        Text(
                          '$v',
                          style: FapText.monoStyle(
                            size: 11,
                            color: FapColors.textDim,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFF050B11),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: FapColors.panelBorder,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          for (final f in [0.25, 0.5, 0.75])
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: c.maxHeight * f,
                              child: Container(
                                height: 1,
                                color: FapColors.panelBorder,
                              ),
                            ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              height: c.maxHeight * (pct / 100).clamp(0, 1),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    color,
                                    Color.lerp(color, Colors.black, 0.45)!,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StatusTag(status, color, size: 13),
          ],
        ),
      ),
    );
  }
}

class _LavTile extends StatelessWidget {
  const _LavTile({required this.lav, required this.fap});
  final Lavatory lav;
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final inop = fap.lavsInop;
    final noWater = fap.waterEmpty;
    final color = inop
        ? FapColors.red
        : (noWater ? FapColors.amber : FapColors.okGreen);
    final text = inop ? 'INOP' : (noWater ? 'NO WATER' : 'OK');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13212E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(
            lav.label,
            style: FapText.monoStyle(size: 16, weight: FontWeight.w700),
          ),
          Text(lav.location, style: FapText.label.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          StatusTag(text, color),
        ],
      ),
    );
  }
}
