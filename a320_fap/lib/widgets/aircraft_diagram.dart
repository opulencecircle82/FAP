import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fap_state.dart';
import '../providers/fap_provider.dart';
import '../theme/fap_theme.dart';
import 'blink.dart';

enum DiagramMode { lighting, doors, smoke }

/// Top-down A320 fuselage schematic, nose up, in Airbus gold.
///
/// In [DiagramMode.lighting] each zone's fill intensity follows its light
/// level; in [DiagramMode.doors] door markers show door/slide state; in
/// [DiagramMode.smoke] lavatories flash red when smoke is detected.
class AircraftDiagram extends StatelessWidget {
  const AircraftDiagram({super.key, required this.mode});

  final DiagramMode mode;

  @override
  Widget build(BuildContext context) {
    final fap = context.watch<FapProvider>();
    final blink = context.watch<Blink>().value;
    // Cabin zones follow the classes of the active CAM layout, sized by
    // their seat rows, between the two entry areas.
    final layout = fap.activeLayout;
    final zones = <_Zone>[const _Zone(LightZone.fwdEntry, 0, 0.10, '')];
    for (var i = 0; i < layout.classes.length; i++) {
      final (first, last) = fap.classRows(i);
      zones.add(
        _Zone(
          FapProvider.zoneOfClass(layout.classes[i]),
          0.10 + 0.80 * (first - 1) / layout.rows,
          0.10 + 0.80 * last / layout.rows,
          layout.classes[i].short,
        ),
      );
    }
    zones.add(const _Zone(LightZone.aftEntry, 0.90, 1.0, ''));
    return CustomPaint(
      painter: _AircraftPainter(
        mode: mode,
        blink: blink,
        zones: zones,
        lights: {for (final z in LightZone.values) z: fap.lightLevel(z)},
        windowLights: fap.windowLights,
        readingLights: fap.readingAll,
        emerLights: fap.emerLights,
        lavMaint: fap.lavMaint,
        doors: {for (final d in DoorId.values) d: fap.door(d)},
        smoke: {for (final l in Lavatory.values) l: fap.smoke(l).alert},
      ),
      size: Size.infinite,
    );
  }
}

class _Zone {
  const _Zone(this.zone, this.from, this.to, this.label);
  final LightZone zone;
  final double from;
  final double to;
  final String label;
}

class _AircraftPainter extends CustomPainter {
  _AircraftPainter({
    required this.mode,
    required this.blink,
    required this.zones,
    required this.lights,
    required this.windowLights,
    required this.readingLights,
    required this.emerLights,
    required this.lavMaint,
    required this.doors,
    required this.smoke,
  });

  final DiagramMode mode;
  final bool blink;
  final List<_Zone> zones;
  final Map<LightZone, LightLevel> lights;
  final bool windowLights;
  final bool readingLights;
  final bool emerLights;
  final bool lavMaint;
  final Map<DoorId, DoorStatus> doors;
  final Map<Lavatory, SmokeAlert> smoke;

  static double zoneAlpha(LightLevel l) => switch (l) {
    LightLevel.off => 0.05,
    LightLevel.dim2 => 0.22,
    LightLevel.dim1 => 0.55,
    LightLevel.bright => 1.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final fw = (w * 0.40).clamp(30.0, h * 0.14);
    final noseLen = fw * 1.25;
    final tailLen = fw * 1.7;
    final bodyTop = noseLen;
    final bodyBottom = h - tailLen;
    final bodyLen = bodyBottom - bodyTop;
    final left = cx - fw / 2;
    final right = cx + fw / 2;

    double at(double f) => bodyTop + bodyLen * f;

    final gold = FapColors.gold;
    final outline = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    // ---- wings & stabilisers (behind fuselage)
    final wingPaint = Paint()..color = gold.withValues(alpha: 0.16);
    final wingRootTop = at(0.36), wingRootBottom = at(0.60);
    final span = (w - fw) / 2 * 0.95;
    for (final s in [-1.0, 1.0]) {
      final rootX = s < 0 ? left : right;
      final wing = Path()
        ..moveTo(rootX, wingRootTop)
        ..lineTo(rootX + s * span, wingRootTop + bodyLen * 0.20)
        ..lineTo(rootX + s * span, wingRootTop + bodyLen * 0.26)
        ..lineTo(rootX, wingRootBottom)
        ..close();
      canvas.drawPath(wing, wingPaint);
      canvas.drawPath(
        wing,
        Paint()
          ..color = gold.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final stabRoot = h - tailLen * 0.55;
      final stab = Path()
        ..moveTo(cx + s * fw * 0.3, stabRoot)
        ..lineTo(cx + s * span * 0.55, stabRoot + tailLen * 0.25)
        ..lineTo(cx + s * span * 0.55, stabRoot + tailLen * 0.35)
        ..lineTo(cx + s * fw * 0.25, stabRoot + tailLen * 0.38)
        ..close();
      canvas.drawPath(stab, wingPaint);
      canvas.drawPath(
        stab,
        Paint()
          ..color = gold.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // ---- fuselage outline
    final body = Path()
      ..moveTo(left, bodyTop)
      ..cubicTo(left, bodyTop - noseLen * 0.55, cx - fw * 0.22, 0, cx, 0)
      ..cubicTo(
        cx + fw * 0.22,
        0,
        right,
        bodyTop - noseLen * 0.55,
        right,
        bodyTop,
      )
      ..lineTo(right, bodyBottom)
      ..cubicTo(
        right,
        bodyBottom + tailLen * 0.5,
        cx + fw * 0.2,
        h - 4,
        cx + fw * 0.12,
        h,
      )
      ..lineTo(cx - fw * 0.12, h)
      ..cubicTo(
        cx - fw * 0.2,
        h - 4,
        left,
        bodyBottom + tailLen * 0.5,
        left,
        bodyBottom,
      )
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFF0D1823));

    // ---- cabin zones
    final inset = 3.5;
    final zoneBounds = <LightZone, Rect>{
      for (final z in zones)
        z.zone: Rect.fromLTRB(
          left + inset,
          at(z.from),
          right - inset,
          at(z.to),
        ),
    };

    for (final e in zoneBounds.entries) {
      final Color fill = switch (mode) {
        DiagramMode.lighting => gold.withValues(
          alpha: zoneAlpha(lights[e.key]!),
        ),
        _ => const Color(0xFF1E3346),
      };
      canvas.drawRect(e.value.deflate(0.8), Paint()..color = fill);
    }
    // zone separators
    final sep = Paint()
      ..color = gold.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (final z in zones.skip(1)) {
      _dashedLine(
        canvas,
        Offset(left + inset, at(z.from)),
        Offset(right - inset, at(z.from)),
        sep,
      );
    }
    // class labels (F/C, B/C, T/C)
    if (mode == DiagramMode.lighting) {
      for (final z in zones.where((z) => z.label.isNotEmpty)) {
        final dark =
            lights[z.zone] == LightLevel.bright ||
            lights[z.zone] == LightLevel.dim1;
        _label(
          canvas,
          z.label,
          Offset(cx, at(z.from) + 9),
          9,
          dark ? Colors.black : gold,
        );
      }
    }

    // cockpit windows
    final cockpit = Paint()..color = gold.withValues(alpha: 0.85);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, bodyTop - noseLen * 0.38),
        width: fw * 0.55,
        height: noseLen * 0.12,
      ),
      cockpit,
    );

    if (mode == DiagramMode.lighting) {
      _paintLightingDetail(canvas, zoneBounds, left, right, at);
    }

    canvas.drawPath(body, outline);

    // ---- lavatories: A forward-left, D and E aft
    final lavSize = fw * 0.26;
    final lavRects = <Lavatory, Rect>{
      Lavatory.a: Rect.fromLTWH(left + inset + 1, at(0.015), lavSize, lavSize),
      Lavatory.d: Rect.fromLTWH(
        left + inset + 1,
        at(0.985) - lavSize,
        lavSize,
        lavSize,
      ),
      Lavatory.e: Rect.fromLTWH(
        right - inset - 1 - lavSize,
        at(0.985) - lavSize,
        lavSize,
        lavSize,
      ),
    };
    for (final e in lavRects.entries) {
      Color c;
      if (mode == DiagramMode.smoke) {
        c = switch (smoke[e.key]!) {
          SmokeAlert.alarm => blink ? FapColors.red : const Color(0xFF5A1010),
          SmokeAlert.reset => FapColors.amber,
          SmokeAlert.normal => FapColors.okGreen,
        };
      } else if (mode == DiagramMode.lighting) {
        c = lavMaint ? Colors.white : const Color(0xFF8C8C8C);
      } else {
        c = const Color(0xFF55697D);
      }
      canvas.drawRect(e.value, Paint()..color = c);
      canvas.drawRect(
        e.value,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _label(
        canvas,
        e.key.name.toUpperCase(),
        e.value.center,
        fw * 0.17,
        Colors.black,
      );
    }

    // ---- doors
    final doorPos = <DoorId, double>{
      DoorId.l1: 0.05,
      DoorId.r1: 0.05,
      DoorId.owL1: 0.45,
      DoorId.owR1: 0.45,
      DoorId.owL2: 0.52,
      DoorId.owR2: 0.52,
      DoorId.l2: 0.95,
      DoorId.r2: 0.95,
    };
    for (final e in doorPos.entries) {
      final id = e.key;
      final d = doors[id]!;
      final isLeft = id.side == DoorSide.left;
      final dh = id.isOverwing ? bodyLen * 0.035 : bodyLen * 0.055;
      final x = isLeft ? left : right;
      final rect = Rect.fromCenter(
        center: Offset(x, at(e.value)),
        width: 7,
        height: dh,
      );

      Color c;
      if (mode == DiagramMode.doors) {
        if (d.slideDeployed) {
          c = blink ? FapColors.red : const Color(0xFF7A1515);
        } else if (!d.closed) {
          c = FapColors.amber;
        } else if (d.armed) {
          c = FapColors.okGreen;
        } else {
          c = Colors.white;
        }
      } else {
        c = const Color(0xFF8899AA);
      }

      if (mode == DiagramMode.doors && d.slideDeployed) {
        final s = isLeft ? -1.0 : 1.0;
        final slideLen = (w - fw) / 2 * 0.85;
        final slide = Path()
          ..moveTo(x, rect.top)
          ..lineTo(x + s * slideLen, rect.center.dy - dh * 0.2)
          ..lineTo(x + s * slideLen, rect.center.dy + dh * 1.4)
          ..lineTo(x, rect.bottom)
          ..close();
        canvas.drawPath(slide, Paint()..color = c.withValues(alpha: 0.75));
      }
      canvas.drawRect(rect, Paint()..color = c);
      if (mode == DiagramMode.doors && !id.isOverwing) {
        _label(
          canvas,
          id.label,
          Offset(x + (isLeft ? -16 : 16), at(e.value)),
          10,
          FapColors.white,
        );
      }
    }

    // ---- emergency lighting: exit signs + floor path marking
    if (emerLights && mode == DiagramMode.lighting) {
      final path = Paint()
        ..color = FapColors.okGreen
        ..strokeWidth = 2;
      _dashedLine(
        canvas,
        Offset(cx, at(0.02)),
        Offset(cx, at(0.98)),
        path,
        dash: 4,
        gap: 4,
      );
      for (final f in [0.05, 0.45, 0.52, 0.95]) {
        for (final sx in [left + inset + 4, right - inset - 4]) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(sx, at(f)), width: 6, height: 4),
            Paint()..color = FapColors.okGreen,
          );
        }
      }
    }
  }

  void _paintLightingDetail(
    Canvas canvas,
    Map<LightZone, Rect> zones,
    double left,
    double right,
    double Function(double) at,
  ) {
    final cabinTop = at(0.10);
    final cabinBottom = at(0.90);

    if (windowLights) {
      final p = Paint()
        ..color = const Color(0xFFE6FBFF)
        ..strokeWidth = 2.2;
      for (final x in [left + 5.5, right - 5.5]) {
        canvas.drawLine(Offset(x, cabinTop + 4), Offset(x, cabinBottom - 4), p);
      }
    }

    // Seat rows: dots (bright warm white when reading lights are on).
    final rows = 24;
    final dot = Paint()
      ..color = readingLights
          ? const Color(0xFFFFF4C2)
          : Colors.black.withValues(alpha: 0.28);
    final fw = right - left;
    for (var r = 0; r < rows; r++) {
      final y = cabinTop + (cabinBottom - cabinTop) * (r + 0.5) / rows;
      for (final fx in [0.2, 0.32, 0.68, 0.8]) {
        canvas.drawCircle(
          Offset(left + fw * fx, y),
          readingLights ? 1.8 : 1.2,
          dot,
        );
      }
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: FapText.mono,
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint p, {
    double dash = 3,
    double gap = 3,
  }) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash + gap) {
      final end = (d + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * d, a + dir * end, p);
    }
  }

  @override
  bool shouldRepaint(covariant _AircraftPainter old) => true;
}
