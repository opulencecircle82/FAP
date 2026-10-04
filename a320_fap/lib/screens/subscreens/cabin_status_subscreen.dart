import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';

/// CABIN STATUS page: one overview tile per system; tap a tile to open
/// that system's page.
class CabinStatusSubscreen extends StatelessWidget {
  const CabinStatusSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    final doorsColor = fap.anySlideDeployed
        ? FapColors.red
        : (fap.allDoorsSecure ? FapColors.okGreen : FapColors.amber);
    final smokeColor = fap.smokeAlarm
        ? FapColors.red
        : (fap.smokeMonitoring ? FapColors.amber : FapColors.okGreen);
    final waterColor = fap.wasteFull || fap.waterEmpty
        ? FapColors.red
        : (fap.waterLow || fap.wasteHigh ? FapColors.amber : FapColors.okGreen);
    final cidsColor = fap.cidsDown
        ? FapColors.red
        : (fap.dir1Fault || fap.dir2Fault
              ? FapColors.amber
              : FapColors.okGreen);
    final general = fap.generalLevel;

    final tiles = <_Tile>[
      _Tile(
        page: FapPage.doors,
        icon: Icons.sensor_door_outlined,
        color: doorsColor,
        lines: [
          'CLOSED ${fap.closedCount}/${DoorId.values.length}',
          'ARMED  ${fap.armedCount}/${DoorId.values.length}',
          if (fap.anySlideDeployed) 'SLIDE DEPLOYED',
        ],
      ),
      _Tile(
        page: FapPage.lights,
        icon: Icons.lightbulb_outline,
        color: fap.mainLightsOn ? FapColors.gold : FapColors.textDim,
        lines: [
          'MAIN ${fap.mainLightsOn ? 'ON' : 'OFF'}',
          'GENERAL ${general?.label ?? (fap.mainLightsOn ? 'MIXED' : 'OFF')}',
          if (fap.emerLights) 'EMER LT ON',
        ],
      ),
      _Tile(
        page: FapPage.audio,
        icon: Icons.campaign_outlined,
        color: fap.cidsDown ? FapColors.red : FapColors.cyan,
        lines: [
          'MUSIC ${fap.musicPlaying ? 'ON' : 'OFF'}',
          'PA ${fap.playingAnnouncement != null ? 'ON AIR' : 'IDLE'}',
        ],
      ),
      _Tile(
        page: FapPage.temperature,
        icon: Icons.thermostat,
        color: FapColors.cyan,
        lines: [
          for (final z in TempZone.values)
            '${z.name.toUpperCase()} ${fap.actualTemp(z).toStringAsFixed(1)}°C',
        ],
      ),
      _Tile(
        page: FapPage.water,
        icon: Icons.water_drop_outlined,
        color: waterColor,
        lines: [
          'WATER ${fap.waterPct.round()}%',
          'WASTE ${fap.wastePct.round()}%',
          if (fap.lavsInop) 'LAVS INOP',
        ],
      ),
      _Tile(
        page: FapPage.smoke,
        icon: Icons.smoke_free,
        color: smokeColor,
        lines: [
          fap.smokeAlarm
              ? 'SMOKE ${fap.smokeLavs.map((l) => l.label).join(' ')}'
              : (fap.smokeMonitoring ? 'MONITORING' : 'NORMAL'),
        ],
      ),
      _Tile(
        page: FapPage.systemInfo,
        icon: Icons.memory,
        color: cidsColor,
        lines: [
          fap.cidsDown ? 'CIDS 1+2 FAULT' : 'DIR ${fap.activeDirector} ACTIVE',
          'PAX SYS ${fap.paxSys ? 'ON' : 'OFF'}',
        ],
      ),
      _Tile(
        page: null,
        icon: Icons.emergency_outlined,
        color: fap.evacActive ? FapColors.red : FapColors.okGreen,
        title: 'EVAC',
        lines: [fap.evacActive ? 'EVAC CMD ACTIVE' : 'NORMAL'],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.15,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final t in tiles) _TileView(tile: t, fap: fap)],
      ),
    );
  }
}

class _Tile {
  const _Tile({
    required this.page,
    required this.icon,
    required this.color,
    required this.lines,
    this.title,
  });

  final FapPage? page;
  final IconData icon;
  final Color color;
  final List<String> lines;
  final String? title;
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile, required this.fap});
  final _Tile tile;
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final title = tile.title ?? tile.page!.title;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tile.page == null ? null : () => fap.goTo(tile.page!),
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FapColors.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tile.color.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(tile.icon, color: tile.color, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: FapText.panelTitle,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              for (final l in tile.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l,
                    style: FapText.monoStyle(
                      size: 20,
                      color: tile.color,
                      weight: FontWeight.w700,
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
