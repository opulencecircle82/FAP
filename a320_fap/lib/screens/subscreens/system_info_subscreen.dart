import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/fap_provider.dart';
import '../../config.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';
import '../landing_page_screen.dart';

/// SYSTEM INFO page: CIDS health and messages, plus trainer fault
/// injection. With both CIDS directors failed, PA, interphone and
/// passenger signs are lost (ECAM: CIDS 1+2 FAULT).
class SystemInfoSubscreen extends StatelessWidget {
  const SystemInfoSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    String dirStatus(int n, bool fault) {
      if (fault) return 'FAULT';
      return fap.activeDirector == n ? 'ACTIVE' : 'STBY';
    }

    Color dirColor(bool fault) => fault ? FapColors.red : FapColors.okGreen;

    final units = <(String, String, Color)>[
      ('CIDS DIRECTOR 1', dirStatus(1, fap.dir1Fault), dirColor(fap.dir1Fault)),
      ('CIDS DIRECTOR 2', dirStatus(2, fap.dir2Fault), dirColor(fap.dir2Fault)),
      ('FAP 1 (FWD)', 'OK', FapColors.okGreen),
      (
        'DEU TYPE A (PAX CABIN)',
        fap.cidsDown ? 'NO DATA' : 'OK',
        fap.cidsDown ? FapColors.amber : FapColors.okGreen,
      ),
      (
        'DEU TYPE B (CREW STATIONS)',
        fap.cidsDown ? 'NO DATA' : 'OK',
        fap.cidsDown ? FapColors.amber : FapColors.okGreen,
      ),
      (
        'PRAM / AUDIO',
        fap.cidsDown ? 'NOT AVAIL' : 'OK',
        fap.cidsDown ? FapColors.red : FapColors.okGreen,
      ),
      (
        'PAX SYSTEMS',
        fap.paxSys ? 'ON' : 'OFF',
        fap.paxSys ? FapColors.okGreen : FapColors.textDim,
      ),
      (
        'PED POWER (IN-SEAT POWER)',
        fap.pedPower ? 'ON' : 'OFF',
        fap.pedPower ? FapColors.okGreen : FapColors.textDim,
      ),
      (
        'EVAC SELECTOR (COCKPIT)',
        fap.evacCaptOnly ? 'CAPT' : 'CAPT & PURS',
        fap.evacCaptOnly ? FapColors.amber : FapColors.white,
      ),
      ('CAM (CABIN ASSIGNMENT MODULE)', 'A320 STD', FapColors.white),
    ];

    final messages = <(String, Color)>[
      if (fap.cidsDown)
        ('CIDS 1+2 FAULT - PA, INTERPHONE, PAX SIGNS LOST', FapColors.red)
      else if (fap.dir1Fault)
        ('CIDS DIR 1 FAULT - DIR 2 TAKES OVER', FapColors.amber)
      else if (fap.dir2Fault)
        ('CIDS DIR 2 FAULT - NO STANDBY', FapColors.amber),
      if (fap.lavsInop) ('WASTE TANK FULL - LAVS INOP', FapColors.amber),
      if (fap.anySlideDeployed) ('SLIDE DEPLOYED', FapColors.red),
      if (fap.screenLocked) ('FAP SCREEN LOCKED', FapColors.white),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 560,
            child: FapPanel(
              title: 'CIDS SYSTEM STATUS',
              child: Column(
                children: [
                  for (final u in units)
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: FapColors.panelBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(u.$1, style: FapText.body)),
                          StatusTag(u.$2, u.$3),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('SOFTWARE', style: FapText.label),
                      const Spacer(),
                      Text(
                        'AISAT FAP SIM v${AppConfig.version}',
                        style: FapText.monoStyle(
                          size: 12,
                          color: FapColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FapPanel(
                  title: 'MESSAGES',
                  child: SizedBox(
                    height: 120,
                    child: messages.isEmpty
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'NO MESSAGES',
                              style: FapText.monoStyle(
                                size: 13,
                                color: FapColors.okGreen,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final m in messages)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    m.$1,
                                    style: FapText.monoStyle(
                                      size: 13,
                                      color: m.$2,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                TrainerBox(
                  label: 'TRAINER  -  FAULT INJECTION',
                  child: Row(
                    children: [
                      FapButton(
                        label: 'DIR 1\nFAULT',
                        width: 120,
                        height: 46,
                        fontSize: 12,
                        active: fap.dir1Fault,
                        onTap: () => fap.toggleDirectorFault(1),
                      ),
                      const SizedBox(width: 12),
                      FapButton(
                        label: 'DIR 2\nFAULT',
                        width: 120,
                        height: 46,
                        fontSize: 12,
                        active: fap.dir2Fault,
                        onTap: () => fap.toggleDirectorFault(2),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Both directors failed = CIDS 1+2 FAULT.',
                          style: FapText.label,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TrainerBox(
                  label: 'TRAINER  -  COCKPIT / AUTOMATIC EVENTS',
                  child: Row(
                    children: [
                      FapButton(
                        label: fap.evacCaptOnly
                            ? 'SELECTOR\nCAPT'
                            : 'SELECTOR\nCAPT & PURS',
                        width: 150,
                        height: 46,
                        fontSize: 12,
                        active: fap.evacCaptOnly,
                        onTap: fap.toggleEvacSelector,
                      ),
                      const SizedBox(width: 12),
                      FapButton(
                        label: 'COCKPIT\nEVAC CMD',
                        width: 130,
                        height: 46,
                        fontSize: 12,
                        onTap: fap.cockpitEvacCommand,
                      ),
                      const SizedBox(width: 12),
                      FapButton(
                        label: 'LOW CABIN\nPRESSURE',
                        width: 130,
                        height: 46,
                        fontSize: 12,
                        onTap: fap.lowCabinPressure,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    FapButton(
                      label: 'AISAT APP HUB',
                      width: 190,
                      height: 50,
                      onTap: () {
                        // Return to the hub if we came from it (web),
                        // otherwise open it (tablet app).
                        final nav = Navigator.of(context);
                        if (nav.canPop()) {
                          nav.pop();
                        } else {
                          nav.pushNamed(LandingPageScreen.route);
                        }
                      },
                    ),
                    const SizedBox(width: 14),
                    FapButton(
                      label: 'RESET SIMULATOR',
                      width: 190,
                      height: 50,
                      tone: FapButtonTone.amber,
                      onTap: () => _confirmReset(context, fap),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, FapProvider fap) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FapColors.panel,
        title: const Text('Reset simulator?', style: FapText.panelTitle),
        content: const Text(
          'All lights, doors, temperatures, water/waste levels and faults '
          'return to their starting state.',
          style: FapText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'RESET',
              style: TextStyle(color: FapColors.amber),
            ),
          ),
        ],
      ),
    );
    if (ok == true) fap.resetSimulator();
  }
}
