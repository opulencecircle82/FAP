import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Demo version lock for the whole panel.
///
/// While [active], a touch anywhere in [child] is blocked (and [onBlocked]
/// is called when the finger lifts) unless it lands inside a [DemoAllowed]
/// widget. Gating at hit-test level covers every control on every page,
/// including the hard keys and the aircraft diagrams, without changing them.
class DemoGate extends SingleChildRenderObjectWidget {
  const DemoGate({
    super.key,
    required this.active,
    required this.onBlocked,
    super.child,
  });

  final bool active;
  final VoidCallback onBlocked;

  @override
  RenderDemoGate createRenderObject(BuildContext context) =>
      RenderDemoGate(active: active, onBlocked: onBlocked);

  @override
  void updateRenderObject(BuildContext context, RenderDemoGate renderObject) {
    renderObject
      ..active = active
      ..onBlocked = onBlocked;
  }
}

/// Marks a control that also works in the demo version.
class DemoAllowed extends SingleChildRenderObjectWidget {
  const DemoAllowed({super.key, super.child});

  @override
  RenderDemoAllowed createRenderObject(BuildContext context) =>
      RenderDemoAllowed();
}

class RenderDemoAllowed extends RenderProxyBox {}

class RenderDemoGate extends RenderProxyBox {
  RenderDemoGate({required this.active, required this.onBlocked});

  bool active;
  VoidCallback onBlocked;

  late final _blocker = _Blocker(this);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!active) return super.hitTest(result, position: position);
    if (!size.contains(position)) return false;
    // Probe first: is the touch on an allowed control?
    final probe = BoxHitTestResult();
    // Empty space around the panel: nothing to block.
    if (!super.hitTest(probe, position: position)) return false;
    if (probe.path.any((e) => e.target is RenderDemoAllowed)) {
      return super.hitTest(result, position: position);
    }
    // Blocked: nothing below receives the touch.
    result.add(HitTestEntry(_blocker));
    return true;
  }
}

class _Blocker implements HitTestTarget {
  _Blocker(this.gate);
  final RenderDemoGate gate;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerUpEvent) gate.onBlocked();
  }
}
