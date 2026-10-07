import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import 'blink.dart';

enum _Led { off, green, amber, red }

/// Physical membrane hard keys below the FAP touchscreen (A320 CIDS):
/// EVAC CMD (guarded), EVAC RESET, EMER, PED POWER, LIGHTS MAIN ON/OFF,
/// LAV MAINT, SCREEN 30 SEC LOCK, SMOKE RESET, FAP RESET and PAX SYS. Hard keys stay usable
/// while the touchscreen is locked.
class HardwareBezelStrip extends StatelessWidget {
  const HardwareBezelStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final blink = context.watch<Blink>().value;

    _Led flash(_Led c, bool on) => on ? (blink ? c : _Led.off) : _Led.off;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB4BBC3), FapColors.bezelDark],
        ),
        border: Border.all(color: const Color(0xFF6E7781)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _EvacCmdKey(
            guardOpen: fap.evacGuardOpen,
            led: flash(_Led.red, fap.evacActive),
            onGuard: fap.toggleEvacGuard,
            onPress: fap.evacCommand,
          ),
          const SizedBox(width: 16),
          _HardKey(
            label: 'EVAC\nRESET',
            led: flash(_Led.red, fap.evacActive),
            onTap: fap.evacReset,
          ),
          const _Divider(),
          _HardKey(
            label: 'EMER',
            led: fap.emerLights ? _Led.amber : _Led.off,
            onTap: fap.toggleEmerLights,
          ),
          const SizedBox(width: 16),
          _HardKey(
            label: 'PED\nPOWER',
            led: fap.pedPower ? _Led.green : _Led.off,
            onTap: fap.togglePedPower,
          ),
          const SizedBox(width: 16),
          _HardKey(
            label: 'LIGHTS\nMAIN ON/OFF',
            led: fap.mainLightsOn ? _Led.green : _Led.off,
            onTap: fap.toggleMainLights,
          ),
          const SizedBox(width: 16),
          _HardKey(
            label: 'LAV\nMAINT',
            led: fap.lavMaint ? _Led.green : _Led.off,
            onTap: fap.toggleLavMaint,
          ),
          const _Divider(),
          _HardKey(
            label: 'SCREEN\n30 SEC LOCK',
            led: fap.screenLocked ? _Led.amber : _Led.off,
            onTap: fap.screenLock,
          ),
          const SizedBox(width: 16),
          _HardKey(
            label: 'SMOKE\nRESET',
            led: fap.smokeAlarm
                ? flash(_Led.red, true)
                : (fap.smokeMonitoring ? _Led.amber : _Led.off),
            onTap: fap.smokeReset,
          ),
          const SizedBox(width: 16),
          _HardKey(
            label: 'FAP\nRESET',
            led: fap.fapRestarting ? flash(_Led.amber, true) : _Led.off,
            onTap: fap.fapReset,
          ),
          const SizedBox(width: 16),
          _HardKey(
            label: 'PAX\nSYS',
            led: fap.paxSys ? _Led.green : _Led.off,
            onTap: fap.togglePaxSys,
          ),
          const Spacer(),
          const _CardSlot(),
        ],
      ),
    );
  }
}

Color _ledColor(_Led l) => switch (l) {
  _Led.off => const Color(0xFF3A3F45),
  _Led.green => FapColors.activeGreen,
  _Led.amber => FapColors.amber,
  _Led.red => FapColors.red,
};

class _LedBar extends StatelessWidget {
  const _LedBar(this.led);
  final _Led led;

  @override
  Widget build(BuildContext context) {
    final c = _ledColor(led);
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
        boxShadow: led == _Led.off
            ? null
            : [BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 8)],
      ),
    );
  }
}

class _KeyLabel extends StatelessWidget {
  const _KeyLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF1B232B),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          height: 1.15,
        ),
      ),
    );
  }
}

class _HardKey extends StatefulWidget {
  const _HardKey({required this.label, required this.led, required this.onTap});

  final String label;
  final _Led led;
  final VoidCallback onTap;

  @override
  State<_HardKey> createState() => _HardKeyState();
}

class _HardKeyState extends State<_HardKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // The whole column (LED, key and printed label) is the touch target.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LedBar(widget.led),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            width: 78,
            height: 50,
            transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _down
                    ? const [Color(0xFF2A3036), Color(0xFF3B434B)]
                    : const [Color(0xFF4F5861), Color(0xFF2B3138)],
              ),
              border: Border.all(color: const Color(0xFF1A1E22), width: 1.5),
              boxShadow: _down
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x88000000),
                        offset: Offset(0, 3),
                        blurRadius: 3,
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 5),
          _KeyLabel(widget.label),
        ],
      ),
    );
  }
}

/// Red EVAC CMD key under a hinged transparent guard: first tap lifts the
/// guard, then the key can be pressed. Tapping the lifted guard closes it.
class _EvacCmdKey extends StatelessWidget {
  const _EvacCmdKey({
    required this.guardOpen,
    required this.led,
    required this.onGuard,
    required this.onPress,
  });

  final bool guardOpen;
  final _Led led;
  final VoidCallback onGuard;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    const keySize = Size(80, 50);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LedBar(led),
        const SizedBox(height: 6),
        SizedBox(
          width: keySize.width + 10,
          height: keySize.height + 4,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: guardOpen ? onPress : onGuard,
                child: Container(
                  width: keySize.width,
                  height: keySize.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE53935), Color(0xFF8E1010)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF3A0606),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88000000),
                        offset: Offset(0, 3),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
              if (!guardOpen)
                // Closed guard: striped transparent cover over the key.
                IgnorePointer(
                  child: Container(
                    width: keySize.width + 10,
                    height: keySize.height + 4,
                    decoration: BoxDecoration(
                      color: const Color(0x55FFE0E0),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0xCCFFFFFF),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'GUARD',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                )
              else
                // Lifted guard, hinged at the top.
                Positioned(
                  top: -20,
                  child: GestureDetector(
                    onTap: onGuard,
                    child: Container(
                      width: keySize.width + 10,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0x66FFE0E0),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xCCFFFFFF),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        const _KeyLabel('EVAC\nCMD'),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: const Color(0xFF79828C),
    );
  }
}

/// Memory card slots of the FAP lower panel: PRAM (announcements),
/// CAM (cabin assignment module) and OBRM (on-board replaceable module).
class _CardSlot extends StatelessWidget {
  const _CardSlot();

  @override
  Widget build(BuildContext context) {
    Widget slot(String name, Color tag) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF1C2127),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF5B636C)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            color: tag,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        slot('PRAM', const Color(0xFF2E7D32)),
        slot('CAM', const Color(0xFF3F51B5)),
        slot('OBRM', const Color(0xFF37474F)),
      ],
    );
  }
}
