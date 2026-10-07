import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// FAP SET-UP: display brightness, loudspeaker and headphone volume, and
/// the touchscreen key click.
class FapSetupSubscreen extends StatelessWidget {
  const FapSetupSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    Widget setting(
      String title,
      int value,
      void Function(int) step, {
      int min = 0,
    }) {
      return Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: FapText.panelTitle),
          const SizedBox(height: 10),
          Container(
            width: 110,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF050B11),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: FapColors.cyan),
            ),
            child: Text(
              '$value%',
              style: FapText.monoStyle(
                size: 20,
                color: FapColors.cyan,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // level bar
              Container(
                width: 22,
                height: 108,
                decoration: BoxDecoration(
                  color: const Color(0xFF050B11),
                  border: Border.all(color: FapColors.panelBorder),
                ),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: value / 100,
                  child: Container(color: FapColors.cyan),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  FapButton(
                    label: '+',
                    icon: Icons.add,
                    width: 64,
                    height: 50,
                    enabled: value < 100,
                    onTap: () => step(10),
                  ),
                  const SizedBox(height: 8),
                  FapButton(
                    label: '-',
                    icon: Icons.remove,
                    width: 64,
                    height: 50,
                    enabled: value > min,
                    onTap: () => step(-10),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          SizedBox(
            width: 300,
            child: FapPanel(
              title: 'DISPLAY',
              titleColor: FapColors.cyan,
              child: Column(
                children: [
                  setting(
                    'BRIGHTNESS',
                    fap.brightness,
                    fap.adjustBrightness,
                    min: 20,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 520,
            child: FapPanel(
              title: 'VOLUME',
              titleColor: FapColors.cyan,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      setting(
                        'LOUDSPEAKER',
                        fap.loudspeaker,
                        fap.adjustLoudspeaker,
                      ),
                      setting('HEADPHONE', fap.headphone, fap.adjustHeadphone),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('TOUCHSCREEN CLICK', style: FapText.panelTitle),
                  const SizedBox(height: 8),
                  FapButton(
                    label: 'ON/OFF',
                    width: 120,
                    height: 50,
                    active: fap.touchClick,
                    onTap: fap.toggleTouchClick,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 170,
            child: Column(
              children: [
                const SizedBox(height: 300),
                FapButton(
                  label: 'DEFAULT',
                  width: 170,
                  height: 50,
                  onTap: fap.setupDefault,
                ),
                const SizedBox(height: 10),
                FapButton(
                  label: 'SAVE',
                  width: 170,
                  height: 50,
                  onTap: fap.saveSetup,
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
