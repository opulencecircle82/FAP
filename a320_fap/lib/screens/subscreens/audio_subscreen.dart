import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pram_item.dart';
import '../../providers/fap_provider.dart';
import '../../services/fap_audio.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/blink.dart';
import '../../widgets/fap_button.dart';

/// AUDIO page: PRAM (pre-recorded announcements), boarding music, PA and
/// music levels. A PA announcement automatically ducks boarding music.
class AudioSubscreen extends StatelessWidget {
  const AudioSubscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 620,
            child: FapPanel(
              title: 'PRAM  -  PRE-RECORDED ANNOUNCEMENTS',
              titleColor: FapColors.cyan,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                children: [
                  for (final item in pramLibrary)
                    _PramRow(item: item, fap: fap),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ControlPanel(fap: fap),
                const SizedBox(height: 14),
                _LevelsPanel(fap: fap),
                const Spacer(),
                _ChimePanel(fap: fap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PramRow extends StatelessWidget {
  const _PramRow({required this.item, required this.fap});
  final PramItem item;
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final selected = fap.selectedPram == item.id;
    final playing = fap.isPramPlaying(item);
    final blink = context.watch<Blink>().value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => fap.selectPram(item.id),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? FapColors.activeGreen : FapColors.inactive,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected
                    ? FapColors.activeGreen
                    : FapColors.inactiveHighlight.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Text(
                  item.code,
                  style: FapText.monoStyle(
                    size: 16,
                    weight: FontWeight.w700,
                    color: selected ? Colors.black : FapColors.cyan,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  item.isMusic ? Icons.music_note : Icons.campaign,
                  size: 20,
                  color: selected ? Colors.black : FapColors.textDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (playing)
                  Opacity(
                    opacity: blink ? 1 : 0.35,
                    child: StatusTag(
                      item.isMusic ? 'PLAYING' : 'ON AIR',
                      selected ? Colors.black : FapColors.activeGreen,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final item = fap.selectedPramItem;
    final playing = fap.isPramPlaying(item);
    return FapPanel(
      title: 'PRAM CONTROL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: const Color(0xFF050B11),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: FapColors.panelBorder),
            ),
            child: Text(
              '${item.code}  ${item.title}',
              overflow: TextOverflow.ellipsis,
              style: FapText.monoStyle(
                size: 14,
                color: playing ? FapColors.activeGreen : FapColors.cyan,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FapButton(
                label: 'PLAY',
                icon: Icons.play_arrow,
                width: 100,
                active: playing,
                enabled: !fap.cidsDown,
                onTap: fap.playSelectedPram,
              ),
              const SizedBox(width: 10),
              FapButton(
                label: 'STOP',
                icon: Icons.stop,
                width: 100,
                onTap: fap.stopSelectedPram,
              ),
              const SizedBox(width: 10),
              FapButton(label: 'STOP ALL', width: 110, onTap: fap.stopAllAudio),
            ],
          ),
          if (fap.cidsDown) ...[
            const SizedBox(height: 8),
            Text(
              'CIDS 1+2 FAULT - PA NOT AVAILABLE',
              style: FapText.monoStyle(
                size: 12,
                color: FapColors.red,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelsPanel extends StatelessWidget {
  const _LevelsPanel({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget slider(String name, double value, ValueChanged<double> onChanged) =>
        Row(
          children: [
            SizedBox(width: 110, child: Text(name, style: FapText.panelTitle)),
            Expanded(
              child: Slider(value: value, divisions: 20, onChanged: onChanged),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.right,
                style: FapText.monoStyle(
                  size: 14,
                  color: FapColors.cyan,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );

    return FapPanel(
      title: 'LEVEL',
      child: Column(
        children: [
          slider('PA GAIN', fap.paGain, fap.setPaGain),
          slider('MUSIC', fap.musicLevel, fap.setMusicLevel),
        ],
      ),
    );
  }
}

class _ChimePanel extends StatelessWidget {
  const _ChimePanel({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    Widget chime(String label, String meaning, ChimeType type) => Expanded(
      child: Column(
        children: [
          FapButton(
            label: label,
            width: double.infinity,
            height: 42,
            fontSize: 12,
            enabled: !fap.cidsDown,
            onTap: () => fap.playChime(type),
          ),
          const SizedBox(height: 4),
          Text(
            meaning,
            textAlign: TextAlign.center,
            style: FapText.label.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );

    return TrainerBox(
      label: 'TRAINER  -  CABIN CHIMES',
      child: Row(
        children: [
          chime('HIGH', 'Passenger call', ChimeType.singleHigh),
          const SizedBox(width: 10),
          chime('HIGH-LOW', 'Crew / interphone call', ChimeType.highLow),
          const SizedBox(width: 10),
          chime('LOW', 'Seat belt / no smoking sign', ChimeType.singleLow),
        ],
      ),
    );
  }
}
