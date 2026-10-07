import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cabin_setup.dart';
import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/access_keypad.dart';
import '../../widgets/fap_button.dart';

/// LAYOUT SELECTION (access code): the cabin layouts stored on the CAM.
/// Select one and press LOAD to make it active; lighting zones, seat rows
/// and level adjustment follow the active layout.
class LayoutSubscreen extends StatelessWidget {
  const LayoutSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    if (!fap.accessGranted(FapPage.layout)) {
      return const AccessKeypad(page: FapPage.layout);
    }
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
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${months[d.month - 1]} ${d.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          SizedBox(
            width: 760,
            child: FapPanel(
              title: 'CAM IN SLOT   Z053H0000010',
              titleColor: FapColors.cyan,
              child: Column(
                children: [
                  for (final l in cabinLayouts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LayoutRow(
                        layout: l,
                        active: fap.activeLayout.id == l.id,
                        selected: fap.pendingLayout == l.id,
                        count: fap.layoutCount(l.id),
                        changed: fap.layoutChanged(l.id) == null
                            ? null
                            : fmt(fap.layoutChanged(l.id)!),
                        onTap: () => fap.selectLayoutRow(l.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FapButton(
                  label: 'LOAD',
                  width: 170,
                  height: 56,
                  tone: fap.pendingLayout != fap.activeLayout.id
                      ? FapButtonTone.amber
                      : FapButtonTone.normal,
                  onTap: fap.loadLayout,
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

class _LayoutRow extends StatelessWidget {
  const _LayoutRow({
    required this.layout,
    required this.active,
    required this.selected,
    required this.count,
    required this.changed,
    required this.onTap,
  });

  final CabinLayout layout;
  final bool active;
  final bool selected;
  final int count;
  final String? changed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.black : Colors.white;
    final dim = selected ? Colors.black54 : FapColors.textDim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: selected ? FapColors.activeGreen : FapColors.inactive,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? FapColors.cyan : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAYOUT ${layout.id}',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      layout.description,
                      style: TextStyle(color: fg, fontSize: 13),
                    ),
                    Text(
                      'A318/A319/A320/A321  -  '
                      '${[for (final c in layout.classes) c.short].join(' / ')}',
                      style: TextStyle(color: dim, fontSize: 12),
                    ),
                    if (count > 0)
                      Text(
                        'LAYOUT ${layout.id} MODIFIED - COUNT '
                        '${count.toString().padLeft(3, '0')}'
                        '${changed == null ? '' : '   $changed'}',
                        style: TextStyle(
                          color: fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  color: Colors.black,
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
