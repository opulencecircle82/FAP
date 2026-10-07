import 'package:flutter/material.dart';

import '../config.dart';
import '../services/access_lock.dart';
import '../theme/fap_theme.dart';

/// Start screen until the device has a license: enter a license code
/// (online, once per device) or start the free demo.
class UnlockScreen extends StatelessWidget {
  const UnlockScreen({super.key, required this.onUnlocked, this.onDemo});

  final VoidCallback onUnlocked;

  /// Starts the demo version; null hides the demo code.
  final VoidCallback? onDemo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FapColors.statusBar,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LicenseCard(
            onUnlocked: onUnlocked,
            onDemo: onDemo,
            restoreOnStart: true,
          ),
        ),
      ),
    );
  }
}

bool _dialogOpen = false;

/// "Enter the license code" window shown when a locked function is touched
/// in the demo version.
Future<void> showLicenseDialog(
  BuildContext context, {
  required VoidCallback onUnlocked,
}) async {
  if (_dialogOpen) return;
  _dialogOpen = true;
  try {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: LicenseCard(
            locked: true,
            onUnlocked: () {
              Navigator.of(dialogContext).pop();
              onUnlocked();
            },
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  } finally {
    _dialogOpen = false;
  }
}

class LicenseCard extends StatefulWidget {
  const LicenseCard({
    super.key,
    required this.onUnlocked,
    this.onDemo,
    this.onClose,
    this.restoreOnStart = false,
    this.locked = false,
  });

  final VoidCallback onUnlocked;
  final VoidCallback? onDemo;
  final VoidCallback? onClose;

  /// First check whether this device was activated before (reinstall).
  final bool restoreOnStart;

  /// Shown from the demo version after touching a locked function.
  final bool locked;

  @override
  State<LicenseCard> createState() => _LicenseCardState();
}

class _LicenseCardState extends State<LicenseCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  String? _note;
  late bool _busy = widget.restoreOnStart;

  @override
  void initState() {
    super.initState();
    if (widget.restoreOnStart) {
      _restore();
    } else {
      _focusField();
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
      _note = 'Checking this device...';
    });
    final result = await AccessLock.restore();
    if (!mounted) return;
    if (result == LicenseResult.ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _note = result == LicenseResult.invalid
          ? null
          : 'Activated this device before? Connect to the internet, '
                'then tap CHECK AGAIN.';
    });
    _focusField();
  }

  // The field is disabled while busy; focus it after it is enabled again.
  void _focusField() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _focus.requestFocus();
  });

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  static String _message(LicenseResult r) => switch (r) {
    LicenseResult.ok => '',
    LicenseResult.invalid =>
      'Invalid license code. Please check and try again.',
    LicenseResult.alreadyUsed =>
      'This code has already been used on another device.',
    LicenseResult.tooManyAttempts =>
      'Too many attempts. Please wait 15 minutes and try again.',
    LicenseResult.offline =>
      'No internet connection. Activation must be done online.',
    LicenseResult.error => 'Activation failed. Please try again later.',
  };

  Future<void> _startDemo() async {
    await AccessLock.startDemo();
    widget.onDemo?.call();
  }

  Future<void> _submit() async {
    if (_busy || _controller.text.trim().isEmpty) return;
    if (AccessLock.isDemoCode(_controller.text)) {
      if (widget.onDemo != null) {
        await _startDemo();
      } else {
        setState(
          () => _error =
              'That is the demo code. Enter your license code to unlock '
              'all functions.',
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _note = null;
    });
    final result = await AccessLock.activate(_controller.text);
    if (!mounted) return;
    if (result == LicenseResult.ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _error = _message(result);
    });
    _focusField();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        decoration: BoxDecoration(
          color: FapColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: locked ? FapColors.amber : FapColors.panelBorder,
            width: locked ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onClose != null)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: FapColors.textDim),
                ),
              ),
            Icon(
              locked ? Icons.lock : Icons.flight,
              color: locked ? FapColors.amber : FapColors.cyan,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              locked
                  ? 'ENTER THE LICENSE CODE'
                  : AppConfig.appName.toUpperCase(),
              textAlign: TextAlign.center,
              style: FapText.title.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              locked
                  ? 'This function is not available in the demo version. '
                        'Enter your license code to unlock all functions. '
                        'Activation needs an internet connection.'
                  : 'Enter your license code to activate the simulator on '
                        'this device. Activation needs an internet '
                        'connection, and each code can be used on one '
                        'device only.',
              textAlign: TextAlign.center,
              style: FapText.label,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: !widget.restoreOnStart,
              enabled: !_busy,
              // Codes are case-sensitive: keep exactly what is typed.
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: FapText.monoStyle(size: 18, weight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'LICENSE CODE',
                hintText: 'A320-xxxxxxxx',
                hintStyle: FapText.monoStyle(size: 18, color: Colors.white24),
                helperText: 'Case-sensitive: type it exactly as given.',
                errorText: _error,
                errorMaxLines: 2,
                filled: true,
                fillColor: const Color(0xFF050B11),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: FapColors.activeGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('ACTIVATE'),
            ),
            if (_note != null) ...[
              const SizedBox(height: 14),
              Text(_note!, textAlign: TextAlign.center, style: FapText.label),
            ],
            if (!_busy && _note != null)
              TextButton(onPressed: _restore, child: const Text('CHECK AGAIN')),
            if (widget.onDemo != null) ...[
              const SizedBox(height: 18),
              _DemoBox(onTry: _busy ? null : _startDemo),
            ],
          ],
        ),
      ),
    );
  }
}

/// The free demo code, shown on the start screen.
class _DemoBox extends StatelessWidget {
  const _DemoBox({required this.onTry});
  final VoidCallback? onTry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF050B11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FapColors.cyan.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'FREE DEMO CODE  ',
                        style: FapText.label,
                      ),
                      TextSpan(
                        text: AccessLock.demoCode,
                        style: FapText.monoStyle(
                          size: 15,
                          color: FapColors.cyan,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Demo: 1 light (MAIN ON/OFF) and 1 audio '
                  '(boarding music) only. No internet needed.',
                  style: FapText.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onTry,
            style: OutlinedButton.styleFrom(
              foregroundColor: FapColors.cyan,
              side: const BorderSide(color: FapColors.cyan),
            ),
            child: const Text('TRY DEMO'),
          ),
        ],
      ),
    );
  }
}
