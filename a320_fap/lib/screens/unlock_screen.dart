import 'package:flutter/material.dart';

import '../config.dart';
import '../services/access_lock.dart';
import '../theme/fap_theme.dart';

/// Asks for a license code the first time the app runs on a device.
/// Activation needs the internet once; each code works on one device.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  String? _note;
  // Starts busy: first checks whether this device was activated before
  // (e.g. the app was uninstalled and installed again).
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _restore();
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

  Future<void> _submit() async {
    if (_busy || _controller.text.trim().isEmpty) return;
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
    return Scaffold(
      backgroundColor: FapColors.statusBar,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
              decoration: BoxDecoration(
                color: FapColors.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FapColors.panelBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.key, color: FapColors.cyan, size: 44),
                  const SizedBox(height: 14),
                  Text(
                    AppConfig.appName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: FapText.title.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your license code to activate the simulator on '
                    'this device. Activation needs an internet connection, '
                    'and each code can be used on one device only.',
                    textAlign: TextAlign.center,
                    style: FapText.label,
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
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
                      hintStyle: FapText.monoStyle(
                        size: 18,
                        color: Colors.white24,
                      ),
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
                    Text(
                      _note!,
                      textAlign: TextAlign.center,
                      style: FapText.label,
                    ),
                  ],
                  if (!_busy && _note != null)
                    TextButton(
                      onPressed: _restore,
                      child: const Text('CHECK AGAIN'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
