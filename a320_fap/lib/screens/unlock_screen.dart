import 'package:flutter/material.dart';

import '../config.dart';
import '../services/access_lock.dart';
import '../theme/fap_theme.dart';

/// Asks for the open code the first time the app runs on a device.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _error = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await AccessLock.unlock(_controller.text);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      // Wrong code: clear it and keep the cursor in the field.
      _controller.clear();
      setState(() {
        _busy = false;
        _error = true;
      });
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FapColors.statusBar,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                  const Icon(
                    Icons.lock_outline,
                    color: FapColors.cyan,
                    size: 44,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppConfig.appName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: FapText.title.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter the open code to use the simulator on this device.',
                    textAlign: TextAlign.center,
                    style: FapText.label,
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_error) setState(() => _error = false);
                    },
                    style: FapText.monoStyle(size: 18, weight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'OPEN CODE',
                      errorText: _error
                          ? 'Wrong code. Please try again.'
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF050B11),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show code' : 'Hide code',
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
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
                    child: const Text('UNLOCK'),
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
