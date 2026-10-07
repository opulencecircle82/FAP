import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cabin_setup.dart';
import '../../models/pram_item.dart';
import '../../providers/fap_provider.dart';
import '../../services/fap_audio.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/blink.dart';
import '../../widgets/fap_button.dart';

/// AUDIO page: boarding music (BGM1 channels), pre-recorded announcements
/// with a MEMO play list, and cabin settings. A PA announcement lowers the
/// boarding music; two announcements never play together.
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
          SizedBox(width: 300, child: _BgmPanel(fap: fap)),
          const SizedBox(width: 16),
          Expanded(child: _PramPanel(fap: fap)),
          const SizedBox(width: 16),
          SizedBox(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CabinSettings(fap: fap),
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

// ---------------------------------------------------------------- BGM

class _BgmPanel extends StatelessWidget {
  const _BgmPanel({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final blink = context.watch<Blink>().value;
    return FapPanel(
      title: 'BOARDING MUSIC  -  BGM1',
      titleColor: FapColors.cyan,
      trailing: StatusTag(
        fap.musicPlaying ? 'ON' : 'OFF',
        fap.musicPlaying ? FapColors.okGreen : FapColors.textDim,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in BgmChannel.values)
            _ListRow(
              text: c.label,
              selected: fap.bgmChannel == c,
              trailing: fap.musicPlaying && fap.bgmChannel == c
                  ? Icon(
                      Icons.music_note,
                      size: 18,
                      color: blink ? Colors.black : Colors.black45,
                    )
                  : null,
              onTap: () => fap.bgmSelect(c),
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FapButton(
                label: 'ON/OFF',
                width: 84,
                height: 92,
                active: fap.musicPlaying,
                onTap: fap.bgmToggle,
              ),
              _UpDown(
                label: 'VOL. ${fap.bgmVolume}',
                onUp: () => fap.bgmVolumeStep(1),
                onDown: () => fap.bgmVolumeStep(-1),
              ),
              _UpDown(
                label: 'CHAN.',
                onUp: () => fap.bgmChannelStep(1),
                onDown: () => fap.bgmChannelStep(-1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'During a PA announcement the music is lowered automatically.',
            style: FapText.label,
          ),
        ],
      ),
    );
  }
}

class _UpDown extends StatelessWidget {
  const _UpDown({
    required this.label,
    required this.onUp,
    required this.onDown,
  });
  final String label;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FapButton(
          label: '+',
          icon: Icons.add,
          width: 76,
          height: 40,
          onTap: onUp,
        ),
        const SizedBox(height: 6),
        FapButton(
          label: '-',
          icon: Icons.remove,
          width: 76,
          height: 40,
          onTap: onDown,
        ),
        const SizedBox(height: 4),
        Text(label, style: FapText.label.copyWith(fontSize: 11)),
      ],
    );
  }
}

// ---------------------------------------------------------------- PRAM

class _PramPanel extends StatelessWidget {
  const _PramPanel({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    final blink = context.watch<Blink>().value;
    final on = fap.onAnnounce;
    PramItem byId(String id) => pramLibrary.firstWhere((p) => p.id == id);

    return FapPanel(
      title: 'PRERECORDED ANNOUNCEMENT',
      titleColor: FapColors.cyan,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ON ANNOUNCE + MEMO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ON ANNOUNCE', style: FapText.label),
                const SizedBox(height: 4),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xFF050B11),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: on != null
                          ? FapColors.activeGreen
                          : FapColors.panelBorder,
                    ),
                  ),
                  child: Text(
                    on == null ? '' : '${on.code}  ${on.title}',
                    overflow: TextOverflow.ellipsis,
                    style: FapText.monoStyle(
                      size: 13,
                      color: blink
                          ? FapColors.activeGreen
                          : FapColors.activeGreen.withValues(alpha: 0.6),
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('MEMO', style: FapText.label),
                    const Spacer(),
                    if (fap.playingAll)
                      const StatusTag('PLAY ALL', FapColors.okGreen, size: 10),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  height: 214,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050B11),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: FapColors.panelBorder),
                  ),
                  child: fap.memo.isEmpty
                      ? const Center(
                          child: Text(
                            'Select an announcement and press  →',
                            style: FapText.label,
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            for (var i = 0; i < fap.memo.length; i++)
                              _ListRow(
                                text:
                                    '${byId(fap.memo[i]).code}  ${byId(fap.memo[i]).title}',
                                selected: fap.memoSelected == i,
                                dense: true,
                                onTap: () => fap.memoSelect(i),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FapButton(
                        label: 'STOP',
                        width: double.infinity,
                        height: 44,
                        fontSize: 12,
                        onTap: fap.stopSelectedPram,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FapButton(
                        label: 'PLAY\nNEXT',
                        width: double.infinity,
                        height: 44,
                        fontSize: 12,
                        enabled: fap.memo.isNotEmpty,
                        onTap: fap.playNext,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FapButton(
                        label: 'PLAY\nALL',
                        width: double.infinity,
                        height: 44,
                        fontSize: 12,
                        active: fap.playingAll,
                        enabled: fap.memo.isNotEmpty || fap.playingAll,
                        onTap: fap.playAll,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FapButton(
                        label: 'CLEAR\nALL',
                        width: double.infinity,
                        height: 44,
                        fontSize: 12,
                        enabled: fap.memo.isNotEmpty,
                        onTap: fap.memoClear,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Arrows between MEMO and SELECT
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 96, 10, 0),
            child: Column(
              children: [
                FapButton(
                  label: '',
                  icon: Icons.arrow_back,
                  width: 50,
                  height: 46,
                  enabled: fap.memo.isNotEmpty,
                  onTap: fap.memoRemove,
                ),
                const SizedBox(height: 8),
                FapButton(
                  label: '',
                  icon: Icons.arrow_forward,
                  width: 50,
                  height: 46,
                  onTap: fap.memoAdd,
                ),
                const SizedBox(height: 18),
                FapButton(
                  label: '',
                  icon: Icons.keyboard_arrow_up,
                  width: 50,
                  height: 40,
                  onTap: () => fap.memoMove(-1),
                ),
                const SizedBox(height: 6),
                FapButton(
                  label: '',
                  icon: Icons.keyboard_arrow_down,
                  width: 50,
                  height: 40,
                  onTap: () => fap.memoMove(1),
                ),
              ],
            ),
          ),
          // SELECT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('SELECT', style: FapText.label),
                const SizedBox(height: 4),
                for (final item in pramLibrary)
                  _ListRow(
                    text: '${item.code}  ${item.title}',
                    selected: fap.selectedPram == item.id,
                    trailing: fap.playingAnnouncement == item.id
                        ? Icon(
                            Icons.campaign,
                            size: 18,
                            color: blink
                                ? (fap.selectedPram == item.id
                                      ? Colors.black
                                      : FapColors.activeGreen)
                                : Colors.transparent,
                          )
                        : null,
                    onTap: () => fap.selectPram(item.id),
                  ),
                const SizedBox(height: 10),
                FapButton(
                  label: 'DIRECT PLAY',
                  width: double.infinity,
                  height: 44,
                  fontSize: 12,
                  active: fap.playingAnnouncement == fap.selectedPram,
                  enabled: !fap.cidsDown,
                  onTap: fap.playSelectedPram,
                ),
                if (fap.cidsDown) ...[
                  const SizedBox(height: 6),
                  Text(
                    'CIDS 1+2 FAULT - PA NOT AVAILABLE',
                    style: FapText.monoStyle(
                      size: 11,
                      color: FapColors.red,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable list row (green when selected, like the FAP list boxes).
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.text,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.dense = false,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: dense ? 34 : 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? FapColors.activeGreen : FapColors.inactive,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- right

class _CabinSettings extends StatelessWidget {
  const _CabinSettings({required this.fap});
  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    return FapPanel(
      title: 'CABIN SETTINGS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FapButton(
                  label: 'CALL\nRESET',
                  width: double.infinity,
                  height: 50,
                  fontSize: 12,
                  tone: fap.paxCalls.isNotEmpty
                      ? FapButtonTone.amber
                      : FapButtonTone.normal,
                  onTap: fap.callReset,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FapButton(
                  label: 'CHIME\nINHIBIT',
                  width: double.infinity,
                  height: 50,
                  fontSize: 12,
                  active: fap.chimeInhibit,
                  onTap: fap.toggleChimeInhibit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fap.paxCalls.isEmpty
                ? 'No passenger call'
                : 'PAX CALL: ${fap.paxCalls.join(', ')}',
            style: fap.paxCalls.isEmpty
                ? FapText.label
                : FapText.monoStyle(
                    size: 12,
                    color: FapColors.cyan,
                    weight: FontWeight.w700,
                  ),
          ),
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
            height: 40,
            fontSize: 11.5,
            enabled: !fap.cidsDown,
            onTap: () => fap.playChime(type),
          ),
          const SizedBox(height: 3),
          Text(
            meaning,
            textAlign: TextAlign.center,
            style: FapText.label.copyWith(fontSize: 10),
          ),
        ],
      ),
    );

    return TrainerBox(
      label: 'TRAINER  -  CABIN CHIMES',
      child: Column(
        children: [
          Row(
            children: [
              chime('HIGH', 'Passenger call', ChimeType.singleHigh),
              const SizedBox(width: 8),
              chime('HIGH-LOW', 'Crew call', ChimeType.highLow),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              chime('LOW', 'Seat belt / NS', ChimeType.singleLow),
              const SizedBox(width: 8),
              chime('EMER CALL', 'Cockpit (3x)', ChimeType.emergency),
            ],
          ),
        ],
      ),
    );
  }
}
