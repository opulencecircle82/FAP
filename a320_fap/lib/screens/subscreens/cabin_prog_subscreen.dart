import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cabin_setup.dart';
import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/access_keypad.dart';
import '../../widgets/fap_button.dart';

/// CABIN PROGRAMMING (access code): move the cabin zone boundaries between
/// passenger classes, set the non-smoker aircraft flag, and SAVE to the CAM.
class CabinProgSubscreen extends StatelessWidget {
  const CabinProgSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    if (!fap.accessGranted(FapPage.cabinProg)) {
      return const AccessKeypad(page: FapPage.cabinProg);
    }
    final layout = fap.activeLayout;
    final starts = fap.draftStarts;
    final count = fap.layoutCount(layout.id);
    final b = fap.selectedBoundary;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ACTIVE LAYOUT: ${layout.id}${count > 0 ? ' MODIFIED' : ''}'
                '  -  COUNT ${count.toString().padLeft(3, '0')}'
                '${fap.programmingDirty ? '   (NOT SAVED)' : ''}',
                textAlign: TextAlign.center,
                style: FapText.monoStyle(
                  size: 13,
                  color: fap.programmingDirty
                      ? FapColors.amber
                      : FapColors.textDim,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 520,
                      child: FapPanel(
                        title: 'CABIN ZONES',
                        titleColor: FapColors.cyan,
                        child: layout.classes.length < 2
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'The active layout has one class only. '
                                  'Load a 2- or 3-class layout on LAYOUT '
                                  'SELECT to program cabin zones.',
                                  style: FapText.body,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Select the boundary, then move it with '
                                    '▲ (forward) / ▼ (aft).',
                                    style: FapText.label,
                                  ),
                                  const SizedBox(height: 10),
                                  for (
                                    var i = 1;
                                    i < layout.classes.length;
                                    i++
                                  )
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: FapButton(
                                        label:
                                            '${layout.classes[i - 1].label}  /  ${layout.classes[i].label}',
                                        width: double.infinity,
                                        height: 46,
                                        fontSize: 12,
                                        active: b == i,
                                        onTap: () => fap.selectBoundary(i),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 96,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF050B11),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: Border.all(
                                              color: FapColors.activeGreen,
                                            ),
                                          ),
                                          child: Text(
                                            'S/R ${starts[b] - 1}  |  S/R ${starts[b]}',
                                            style: FapText.monoStyle(
                                              size: 22,
                                              color: FapColors.activeGreen,
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        children: [
                                          FapButton(
                                            label: '',
                                            icon: Icons.keyboard_arrow_up,
                                            width: 64,
                                            height: 45,
                                            onTap: () => fap.moveBoundary(-1),
                                          ),
                                          const SizedBox(height: 6),
                                          FapButton(
                                            label: '',
                                            icon: Icons.keyboard_arrow_down,
                                            width: 64,
                                            height: 45,
                                            onTap: () => fap.moveBoundary(1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  for (
                                    var i = 0;
                                    i < layout.classes.length;
                                    i++
                                  )
                                    Builder(
                                      builder: (_) {
                                        final (f, l) = fap.classRows(i, starts);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            '${layout.classes[i].label.padRight(15)} '
                                            'S/R $f - $l  (${l - f + 1} rows)',
                                            style: FapText.monoStyle(size: 13),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FapPanel(
                            title: 'NON SMOKER A/C',
                            child: FapButton(
                              label: 'ON/OFF',
                              width: double.infinity,
                              height: 50,
                              active: fap.draftNonSmoker,
                              onTap: fap.toggleNonSmokerDraft,
                            ),
                          ),
                          const Spacer(),
                          FapButton(
                            label: 'SAVE',
                            width: double.infinity,
                            height: 56,
                            tone: fap.programmingDirty
                                ? FapButtonTone.amber
                                : FapButtonTone.normal,
                            onTap: fap.saveProgramming,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SeatMap(layout: layout, starts: starts),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (fap.savedInfo != null) _SavedDialog(fap: fap),
      ],
    );
  }
}

/// Classes drawn as bands along the cabin with their seat-row limits.
class _SeatMap extends StatelessWidget {
  const _SeatMap({required this.layout, required this.starts});
  final CabinLayout layout;
  final List<int> starts;

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF8E7CC3), Color(0xFF00A2E8), Color(0xFF00C853)];
    return FapPanel(
      title: 'CABIN  (S/R 1 - ${layout.rows})',
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight.isFinite ? c.maxHeight - 10 : 440.0;
          return SizedBox(
            height: h,
            child: Column(
              children: [
                for (var i = 0; i < layout.classes.length; i++)
                  Builder(
                    builder: (_) {
                      final first = starts[i];
                      final last = i + 1 < starts.length
                          ? starts[i + 1] - 1
                          : layout.rows;
                      return Expanded(
                        flex: last - first + 1,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: colors[layout.classes[i].index].withValues(
                              alpha: 0.25,
                            ),
                            border: Border.all(
                              color: colors[layout.classes[i].index],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Text(
                                layout.classes[i].short,
                                style: FapText.monoStyle(
                                  size: 16,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'S/R $first - $last',
                                style: FapText.monoStyle(
                                  size: 13,
                                  color: FapColors.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SavedDialog extends StatelessWidget {
  const _SavedDialog({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final info = fap.savedInfo!;
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final d = info.date;
    final date =
        '${d.day.toString().padLeft(2, '0')}.${months[d.month - 1]} ${d.year}';
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 140, child: Text(k, style: FapText.title)),
          Text(':   $v', style: FapText.title),
        ],
      ),
    );
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xAA000000),
        child: Center(
          child: Container(
            width: 640,
            padding: const EdgeInsets.fromLTRB(40, 34, 40, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF2B3A8C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF5C6BC0), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SAVING COMPLETED',
                  style: FapText.title.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 16),
                line('LAYOUT', 'CAM ${info.layout} MODIFIED'),
                line('COUNT', info.count.toString().padLeft(3, '0')),
                line('DATE', date),
                const SizedBox(height: 20),
                const Text('PRESS OK TO CONTINUE', style: FapText.label),
                const SizedBox(height: 10),
                FapButton(
                  label: 'OK',
                  width: 120,
                  height: 50,
                  onTap: fap.dismissSaved,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
