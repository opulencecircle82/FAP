import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fap_state.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/aircraft_diagram.dart';
import '../../widgets/blink.dart';
import '../../widgets/fap_button.dart';

/// DOORS / SLIDES page. The FAP only displays door and slide status; the
/// dashed TRAINER controls simulate what the crew does at the door itself
/// (arming lever, opening/closing).
class DoorsSubscreen extends StatelessWidget {
  const DoorsSubscreen({super.key});

  static const _left = [DoorId.l1, DoorId.owL1, DoorId.owL2, DoorId.l2];
  static const _right = [DoorId.r1, DoorId.owR1, DoorId.owR2, DoorId.r2];

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryBar(fap: fap),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _DoorColumn(ids: _left)),
                const SizedBox(width: 20),
                const SizedBox(
                  width: 230,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: AircraftDiagram(mode: DiagramMode.doors),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: _DoorColumn(ids: _right)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TrainerBox(
            label: 'TRAINER  -  CABIN CREW COMMANDS',
            child: Row(
              children: [
                FapButton(
                  label: 'ARM SLIDES\nX-CHECK',
                  width: 150,
                  height: 42,
                  fontSize: 12,
                  onTap: fap.armAllSlides,
                ),
                const SizedBox(width: 12),
                FapButton(
                  label: 'DISARM SLIDES\nX-CHECK',
                  width: 150,
                  height: 42,
                  fontSize: 12,
                  onTap: fap.disarmAllSlides,
                ),
                const SizedBox(width: 12),
                FapButton(
                  label: 'RESET DRILL',
                  width: 150,
                  height: 42,
                  fontSize: 12,
                  tone: fap.anySlideDeployed
                      ? FapButtonTone.amber
                      : FapButtonTone.normal,
                  onTap: fap.resetDoorsDrill,
                ),
                const SizedBox(width: 20),
                const Expanded(child: _Legend()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final total = DoorId.values.length;
    final Color color;
    final String text;
    if (fap.anySlideDeployed) {
      color = FapColors.red;
      text =
          'SLIDE DEPLOYED: '
          '${fap.deployedDoors.map((d) => d.label).join(', ')}';
    } else if (fap.allDoorsSecure) {
      color = FapColors.okGreen;
      text = 'ALL DOORS CLOSED  -  ALL SLIDES ARMED';
    } else {
      color = FapColors.amber;
      text = 'CHECK DOOR / SLIDE STATUS';
    }
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FapColors.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: FapText.monoStyle(
                size: 14,
                color: color,
                weight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'CLOSED ${fap.closedCount}/$total',
            style: FapText.monoStyle(size: 13, color: FapColors.textDim),
          ),
          const SizedBox(width: 20),
          Text(
            'ARMED ${fap.armedCount}/$total',
            style: FapText.monoStyle(size: 13, color: FapColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _DoorColumn extends StatelessWidget {
  const _DoorColumn({required this.ids});
  final List<DoorId> ids;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < ids.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Expanded(child: _DoorCard(id: ids[i])),
        ],
      ],
    );
  }
}

class _DoorCard extends StatelessWidget {
  const _DoorCard({required this.id});
  final DoorId id;

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final blink = context.watch<Blink>().value;
    final d = fap.door(id);

    final Color doorColor;
    final String doorText;
    if (d.slideDeployed) {
      doorColor = FapColors.red;
      doorText = 'OPEN';
    } else if (d.closed) {
      doorColor = FapColors.okGreen;
      doorText = id.isOverwing ? 'LOCKED' : 'CLOSED';
    } else {
      doorColor = FapColors.amber;
      doorText = 'OPEN';
    }

    final Color slideColor;
    final String slideText;
    if (d.slideDeployed) {
      slideColor = FapColors.red;
      slideText = 'DEPLOYED';
    } else if (d.armed) {
      slideColor = FapColors.okGreen;
      slideText = 'ARMED';
    } else {
      slideColor = FapColors.white;
      slideText = 'DISARMED';
    }

    final border = d.slideDeployed
        ? (blink ? FapColors.red : FapColors.panelBorder)
        : (d.isSecure
              ? FapColors.panelBorder
              : FapColors.amber.withValues(alpha: 0.6));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: FapColors.panel,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id.label,
                  style: FapText.monoStyle(size: 17, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  id.description,
                  style: FapText.label.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusLine('DOOR ', doorText, doorColor, false),
                const SizedBox(height: 6),
                _statusLine('SLIDE', slideText, slideColor, d.slideDeployed),
              ],
            ),
          ),
          TrainerBox(
            label: 'AT DOOR',
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FapButton(
                  label: id.isOverwing
                      ? 'AUTO ARM'
                      : (d.armed ? 'DISARM' : 'ARM'),
                  width: 86,
                  height: 26,
                  fontSize: 10.5,
                  enabled: !id.isOverwing && !d.slideDeployed,
                  onTap: () => fap.toggleSlideArm(id),
                ),
                const SizedBox(height: 5),
                FapButton(
                  label: d.closed ? 'OPEN' : 'CLOSE',
                  width: 86,
                  height: 26,
                  fontSize: 10.5,
                  enabled: !d.slideDeployed,
                  onTap: () => fap.operateDoor(id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(String k, String v, Color c, bool flashing) => Row(
    children: [
      SizedBox(
        width: 50,
        child: Text(
          k,
          style: FapText.monoStyle(size: 11, color: FapColors.textDim),
        ),
      ),
      StatusTag(v, c, flashing: flashing),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 14, color: c),
          const SizedBox(width: 5),
          Text(t, style: FapText.label.copyWith(fontSize: 11)),
        ],
      ),
    );
    return Wrap(
      runSpacing: 4,
      children: [
        item(FapColors.okGreen, 'CLOSED + ARMED'),
        item(Colors.white, 'CLOSED + DISARMED'),
        item(FapColors.amber, 'OPEN'),
        item(FapColors.red, 'SLIDE DEPLOYED'),
      ],
    );
  }
}
