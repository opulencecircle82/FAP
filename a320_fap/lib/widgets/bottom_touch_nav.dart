import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import 'demo_gate.dart';
import 'fap_button.dart';

/// Touchscreen page selector along the bottom of the FAP display. Like the
/// real FAP it has two rows of pages: the cabin pages and the CAM /
/// maintenance pages; the arrows switch rows. A page with an active alert
/// flashes red or amber.
class BottomTouchNav extends StatelessWidget {
  const BottomTouchNav({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final pages = FapPage.values.where((p) => p.bank == fap.bank).toList();

    FapButtonTone toneFor(FapPage p) {
      switch (p) {
        case FapPage.smoke:
          if (fap.smokeAlarm) return FapButtonTone.red;
          if (fap.smokeMonitoring) return FapButtonTone.amber;
        case FapPage.doors:
          if (fap.anySlideDeployed) return FapButtonTone.red;
        case FapPage.water:
          if (fap.wasteFull) return FapButtonTone.amber;
        case FapPage.seat:
          if (fap.paxCalls.isNotEmpty) return FapButtonTone.amber;
        case FapPage.systemInfo:
          if (fap.cidsDown) return FapButtonTone.red;
          if (fap.dir1Fault || fap.dir2Fault) return FapButtonTone.amber;
        default:
          break;
      }
      return FapButtonTone.normal;
    }

    return Container(
      height: 66,
      color: FapColors.statusBar,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Column(
        children: [
          // Row indicator: which of the two page rows is shown.
          Center(
            child: SizedBox(
              width: 360,
              height: 6,
              child: Row(
                children: [
                  for (final b in [1, 2])
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: fap.bank == b
                              ? FapColors.activeGreen
                              : FapColors.inactive,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                FapButton(
                  label: '',
                  icon: Icons.arrow_left,
                  width: 54,
                  height: 44,
                  onTap: fap.bank > 1 ? () => fap.setBank(1) : null,
                ),
                const SizedBox(width: 8),
                for (final p in pages)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final tone = toneFor(p);
                          final button = FapButton(
                            label: p.tabLabel,
                            width: c.maxWidth,
                            height: 44,
                            fontSize: 11.5,
                            active: fap.page == p,
                            tone: fap.page == p ? FapButtonTone.normal : tone,
                            flashing: tone == FapButtonTone.red,
                            onTap: () => fap.goTo(p),
                          );
                          // Demo version: only these two pages.
                          return p == FapPage.lights || p == FapPage.audio
                              ? DemoAllowed(child: button)
                              : button;
                        },
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                FapButton(
                  label: '',
                  icon: Icons.arrow_right,
                  width: 54,
                  height: 44,
                  onTap: fap.bank < 2 ? () => fap.setBank(2) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
