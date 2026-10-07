import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cabin_setup.dart';
import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/access_keypad.dart';
import '../../widgets/fap_button.dart';

/// LEVEL ADJUSTMENT (access code): announcement and chime loudspeaker
/// levels per cabin zone, attendant area and lavatory (-6 … +6 dB). The
/// cabin zone levels change how loud PA announcements and chimes play.
class LevelSubscreen extends StatelessWidget {
  const LevelSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    if (!fap.accessGranted(FapPage.level)) {
      return const AccessKeypad(page: FapPage.level);
    }
    final areas = fap.levelAreas;
    final sel = fap.levelSelected.clamp(0, areas.length - 1);
    final current = fap.level(areas[sel]);
    String db(int v) => '${v >= 0 ? '+' : ''}$v dB';

    Widget volume(String title, int value, void Function(int) step) => Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: FapText.label),
        const SizedBox(height: 6),
        Container(
          width: 96,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF050B11),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: FapColors.cyan),
          ),
          child: Text(
            db(value),
            style: FapText.monoStyle(
              size: 16,
              color: FapColors.cyan,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FapButton(
          label: '+',
          icon: Icons.add,
          width: 70,
          height: 44,
          enabled: value < SetupLimits.maxDb,
          onTap: () => step(1),
        ),
        const SizedBox(height: 6),
        FapButton(
          label: '-',
          icon: Icons.remove,
          width: 70,
          height: 44,
          enabled: value > SetupLimits.minDb,
          onTap: () => step(-1),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FapPanel(
              title: 'VOLUME ADJUSTMENT  -  ${fap.levelGroup.label}',
              titleColor: FapColors.cyan,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('AREA', style: FapText.label),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text('ANNOUNCE', style: FapText.label),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('CHIME', style: FapText.label),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (var i = 0; i < areas.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => fap.levelSelect(i),
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == sel
                                        ? FapColors.activeGreen
                                        : FapColors.inactive,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: DefaultTextStyle.merge(
                                    style: TextStyle(
                                      color: i == sel
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(areas[i])),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            db(fap.level(areas[i]).announce),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            db(fap.level(areas[i]).chime),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    children: [
                      FapButton(
                        label: '',
                        icon: Icons.keyboard_arrow_up,
                        width: 60,
                        height: 44,
                        onTap: () => fap.levelSelect(sel - 1),
                      ),
                      const SizedBox(height: 6),
                      FapButton(
                        label: '',
                        icon: Icons.keyboard_arrow_down,
                        width: 60,
                        height: 44,
                        onTap: () => fap.levelSelect(sel + 1),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  volume(
                    'ANNOUNCE\nVOLUME',
                    current.announce,
                    (d) => fap.adjustLevel(announce: d),
                  ),
                  const SizedBox(width: 16),
                  volume(
                    'CHIME\nVOLUME',
                    current.chime,
                    (d) => fap.adjustLevel(chime: d),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final g in LevelGroup.values) ...[
                  FapPanel(
                    title: g.label,
                    child: FapButton(
                      label: 'ADJUST',
                      width: double.infinity,
                      height: 44,
                      active: fap.levelGroup == g,
                      onTap: () => fap.setLevelGroup(g),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const Spacer(),
                FapButton(
                  label: 'DEFAULT',
                  width: double.infinity,
                  height: 46,
                  onTap: fap.levelsDefault,
                ),
                const SizedBox(height: 8),
                FapButton(
                  label: 'SAVE',
                  width: double.infinity,
                  height: 46,
                  onTap: fap.saveLevels,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
