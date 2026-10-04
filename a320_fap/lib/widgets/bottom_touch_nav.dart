import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import 'fap_button.dart';

/// Touchscreen page selector along the bottom of the FAP display.
/// A page with an active alert flashes red or amber.
class BottomTouchNav extends StatelessWidget {
  const BottomTouchNav({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final pages = FapPage.values;
    final index = pages.indexOf(fap.page);

    FapButtonTone toneFor(FapPage p) {
      switch (p) {
        case FapPage.smoke:
          if (fap.smokeAlarm) return FapButtonTone.red;
          if (fap.smokeMonitoring) return FapButtonTone.amber;
        case FapPage.doors:
          if (fap.anySlideDeployed) return FapButtonTone.red;
        case FapPage.water:
          if (fap.wasteFull) return FapButtonTone.amber;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          FapButton(
            label: '',
            icon: Icons.arrow_left,
            width: 54,
            height: 50,
            onTap: index > 0 ? () => fap.goTo(pages[index - 1]) : null,
          ),
          const SizedBox(width: 8),
          for (final p in pages)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final tone = toneFor(p);
                    return FapButton(
                      label: p.tabLabel,
                      width: c.maxWidth,
                      height: 50,
                      fontSize: 12,
                      active: fap.page == p,
                      tone: fap.page == p ? FapButtonTone.normal : tone,
                      flashing: tone == FapButtonTone.red,
                      onTap: () => fap.goTo(p),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(width: 8),
          FapButton(
            label: '',
            icon: Icons.arrow_right,
            width: 54,
            height: 50,
            onTap: index < pages.length - 1
                ? () => fap.goTo(pages[index + 1])
                : null,
          ),
        ],
      ),
    );
  }
}
