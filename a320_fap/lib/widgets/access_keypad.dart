import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cabin_setup.dart';
import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import 'fap_button.dart';

/// ENTER ACCESS CODE keypad shown before a protected CAM / maintenance
/// page opens.
class AccessKeypad extends StatefulWidget {
  const AccessKeypad({super.key, required this.page});
  final FapPage page;

  @override
  State<AccessKeypad> createState() => _AccessKeypadState();
}

class _AccessKeypadState extends State<AccessKeypad> {
  String _code = '';

  void _key(String k) {
    if (_code.length < 6) setState(() => _code += k);
  }

  void _enter(FapProvider fap) {
    if (!fap.enterAccessCode(widget.page, _code)) setState(() => _code = '');
  }

  @override
  Widget build(BuildContext context) {
    final fap = context.read<FapProvider>();
    Widget key(String label, VoidCallback? onTap, {bool active = false}) =>
        Padding(
          padding: const EdgeInsets.all(4),
          child: FapButton(
            label: label,
            width: 80,
            height: 56,
            fontSize: 18,
            active: active,
            onTap: onTap,
          ),
        );

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: FapPanel(
              title: 'ENTER ACCESS CODE',
              titleColor: FapColors.cyan,
              child: Column(
                children: [
                  Container(
                    height: 46,
                    margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF050B11),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: FapColors.panelBorder),
                    ),
                    child: Text(
                      '*' * _code.length,
                      style: FapText.monoStyle(
                        size: 24,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [for (final k in row) key(k, () => _key(k))],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      key('CLEAR', () => setState(() => _code = '')),
                      key('0', () => _key('0')),
                      key('ENTER', _code.isEmpty ? null : () => _enter(fap)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ACTIVE LAYOUT: ${fap.activeLayout.id} '
                    '${fap.layoutCount(fap.activeLayout.id) > 0 ? 'MODIFIED' : 'STANDARD'}',
                    style: FapText.label,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 30),
          SizedBox(
            width: 300,
            child: TrainerBox(
              label: 'TRAINER  -  ACCESS CODES',
              child: Text(
                'CIDS default codes:\n'
                '${SetupLimits.programmingCode} - Cabin Prog, Layout Select, '
                'Level Adjust\n'
                '${SetupLimits.softwareCode} - SW Load\n\n'
                'Access is kept until FAP RESET.',
                style: FapText.body.copyWith(fontSize: 13, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
