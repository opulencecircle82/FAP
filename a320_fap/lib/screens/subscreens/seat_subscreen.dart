import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cabin_setup.dart';
import '../../providers/fap_provider.dart';
import '../../theme/fap_theme.dart';
import '../../widgets/fap_button.dart';

/// SEAT SETTINGS page: inhibit the passenger call button or the reading
/// light of single seats (e.g. a broken button), plus cabin-wide call
/// inhibit, chime inhibit and passenger entertainment (PES) power.
class SeatSubscreen extends StatefulWidget {
  const SeatSubscreen({super.key});

  @override
  State<SeatSubscreen> createState() => _SeatSubscreenState();
}

class _SeatSubscreenState extends State<SeatSubscreen> {
  int _row = 1;
  String? _letter;
  String? _inhibitedSel;

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final rows = fap.activeLayout.rows;
    if (_row > rows) _row = 1;
    final seat = _letter == null ? null : '$_row$_letter';
    final inhibited = fap.inhibitedSeats.toList()
      ..sort((a, b) {
        final ra = int.parse(a.substring(0, a.length - 1));
        final rb = int.parse(b.substring(0, b.length - 1));
        return ra != rb ? ra.compareTo(rb) : a.compareTo(b);
      });
    final mode = fap.seatReadingMode ? 'READING LIGHT' : 'PASSENGER CALL';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FapPanel(
              title: '$mode SETTINGS',
              titleColor: FapColors.cyan,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INHIBITED SEATS
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('INHIBITED SEATS', style: FapText.label),
                        const SizedBox(height: 4),
                        _Box(
                          height: 330,
                          child: inhibited.isEmpty
                              ? const Center(
                                  child: Text('None', style: FapText.label),
                                )
                              : ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    for (final s in inhibited)
                                      _Row(
                                        text: 'SEAT $s',
                                        selected: _inhibitedSel == s,
                                        onTap: () =>
                                            setState(() => _inhibitedSel = s),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FapButton(
                                label: 'ENABLE',
                                width: double.infinity,
                                height: 44,
                                fontSize: 12,
                                enabled:
                                    _inhibitedSel != null &&
                                    inhibited.contains(_inhibitedSel),
                                onTap: () {
                                  fap.enableSeat(_inhibitedSel!);
                                  setState(() => _inhibitedSel = null);
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FapButton(
                                label: 'ENABLE\nALL',
                                width: double.infinity,
                                height: 44,
                                fontSize: 12,
                                enabled: inhibited.isNotEmpty,
                                onTap: () {
                                  fap.enableAllSeats();
                                  setState(() => _inhibitedSel = null);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // SEAT ROW
                  SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('SEAT ROW', style: FapText.label),
                        const SizedBox(height: 4),
                        _Box(
                          height: 390,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (var r = 1; r <= rows; r++)
                                _Row(
                                  text: 'SR $r  ${fap.classOfRow(r).short}',
                                  selected: _row == r,
                                  onTap: () => setState(() => _row = r),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // SEAT IDENTIFIER
                  SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('SEAT IDENT.', style: FapText.label),
                        const SizedBox(height: 4),
                        for (final l in seatLetters)
                          _Row(
                            text: 'SEAT $l',
                            selected: _letter == l,
                            onTap: () => setState(() => _letter = l),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // SELECTION + INHIBIT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('SELECTED SEAT', style: FapText.label),
                        const SizedBox(height: 4),
                        Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF050B11),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: FapColors.panelBorder),
                          ),
                          child: Text(
                            seat == null
                                ? 'SR $_row  -'
                                : 'SR $_row  SEAT $_letter',
                            style: FapText.monoStyle(
                              size: 18,
                              color: FapColors.cyan,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FapButton(
                          label: 'INHIBIT',
                          width: double.infinity,
                          height: 50,
                          enabled:
                              seat != null &&
                              !fap.inhibitedSeats.contains(seat),
                          onTap: () => fap.inhibitSeat(seat!),
                        ),
                        const SizedBox(height: 8),
                        FapButton(
                          label: 'CLEAR',
                          width: double.infinity,
                          height: 44,
                          onTap: () => setState(() => _letter = null),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          fap.seatReadingMode
                              ? 'An inhibited reading light stays off, even '
                                    'with R/L SET.'
                              : 'An inhibited call button is ignored (for '
                                    'example a faulty button).',
                          style: FapText.label,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FapPanel(
                  title: 'SETTING FOR',
                  child: Row(
                    children: [
                      Expanded(
                        child: FapButton(
                          label: 'PASSENGER\nCALL',
                          width: double.infinity,
                          height: 50,
                          fontSize: 12,
                          active: !fap.seatReadingMode,
                          onTap: () {
                            fap.setSeatMode(false);
                            setState(() => _inhibitedSel = null);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FapButton(
                          label: 'READING\nLIGHT',
                          width: double.infinity,
                          height: 50,
                          fontSize: 12,
                          active: fap.seatReadingMode,
                          onTap: () {
                            fap.setSeatMode(true);
                            setState(() => _inhibitedSel = null);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FapPanel(
                  title: 'CABIN SETTINGS',
                  child: Row(
                    children: [
                      for (final (label, active, onTap) in [
                        (
                          'CALL\nINHIBIT',
                          fap.callInhibitAll,
                          fap.toggleCallInhibitAll,
                        ),
                        (
                          'CHIME\nINHIBIT',
                          fap.chimeInhibit,
                          fap.toggleChimeInhibit,
                        ),
                        ('PES\nON/OFF', fap.paxSys, fap.togglePaxSys),
                      ]) ...[
                        Expanded(
                          child: FapButton(
                            label: label,
                            width: double.infinity,
                            height: 50,
                            fontSize: 11.5,
                            active: active,
                            onTap: onTap,
                          ),
                        ),
                        if (label != 'PES\nON/OFF') const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                TrainerBox(
                  label: 'TRAINER  -  PASSENGER CALLS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FapButton(
                        label: 'PASSENGER\nPRESSES CALL',
                        width: double.infinity,
                        height: 50,
                        fontSize: 12,
                        onTap: fap.simulatePaxCall,
                      ),
                      const SizedBox(height: 8),
                      FapButton(
                        label: 'CALL RESET',
                        width: double.infinity,
                        height: 44,
                        fontSize: 12,
                        tone: fap.paxCalls.isNotEmpty
                            ? FapButtonTone.amber
                            : FapButtonTone.normal,
                        onTap: fap.callReset,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fap.paxCalls.isEmpty
                            ? 'No active call'
                            : 'ACTIVE: ${fap.paxCalls.join(', ')}',
                        style: FapText.monoStyle(
                          size: 12,
                          color: fap.paxCalls.isEmpty
                              ? FapColors.textDim
                              : FapColors.cyan,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF050B11),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: FapColors.panelBorder),
    ),
    child: child,
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.text, required this.selected, required this.onTap});
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 34,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? FapColors.activeGreen : FapColors.inactive,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
