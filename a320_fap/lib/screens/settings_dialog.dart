import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/access_lock.dart';
import '../theme/fap_theme.dart';

/// Gear-icon settings: shows the license on this device and lets the
/// owner deactivate it here to activate it on another device.
Future<void> showSettingsDialog(
  BuildContext context, {
  required VoidCallback onDeactivated,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: _SettingsCard(
          onClose: () => Navigator.of(dialogContext).pop(),
          onDeactivated: () {
            Navigator.of(dialogContext).pop();
            onDeactivated();
          },
        ),
      ),
    ),
  );
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({required this.onClose, required this.onDeactivated});

  final VoidCallback onClose;
  final VoidCallback onDeactivated;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  String? _code;
  String? _device;
  DateTime? _since;
  bool _loading = true;
  bool _busy = false;
  String? _info; // shown when the server could not be reached
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await AccessLock.savedCode();
    final device = await AccessLock.deviceId();
    if (!mounted) return;
    setState(() {
      _code = saved;
      _device = device;
    });
    final info = await AccessLock.licenseInfo();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (info.result == LicenseResult.ok) {
        _code = info.code ?? _code;
        _since = info.usedAt;
      } else if (info.result == LicenseResult.offline) {
        _info = 'Offline: connect to the internet to check the license.';
      } else if (info.result == LicenseResult.invalid) {
        _info = 'The server has no license for this device.';
      } else {
        _info = 'Could not reach the license server.';
      }
    });
  }

  Future<void> _deactivate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: FapColors.panel,
        title: const Text('Deactivate license?', style: FapText.panelTitle),
        content: const Text(
          'Deactivating will lock this device and allow your code to be '
          'activated on a new machine. Proceed?',
          style: FapText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: FapColors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('DEACTIVATE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AccessLock.deactivate();
    if (!mounted) return;
    if (result == LicenseResult.ok) {
      widget.onDeactivated();
      return;
    }
    setState(() {
      _busy = false;
      _error = result == LicenseResult.offline
          ? 'No internet connection. Deactivation must be done online.'
          : 'Deactivation failed. Please try again later.';
    });
  }

  Widget _row(String label, String value, {bool copy = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FapText.label),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: FapText.monoStyle(size: 14, weight: FontWeight.w700),
              ),
            ),
            if (copy)
              IconButton(
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.copy,
                  size: 18,
                  color: FapColors.textDim,
                ),
                onPressed: () => Clipboard.setData(ClipboardData(text: value)),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final since = _since;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 18, 18, 24),
        decoration: BoxDecoration(
          color: FapColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FapColors.panelBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: FapColors.cyan),
                const SizedBox(width: 10),
                const Expanded(child: Text('SETTINGS', style: FapText.title)),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : widget.onClose,
                  icon: const Icon(Icons.close, color: FapColors.textDim),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(
                    'LICENSE CODE',
                    _code ?? (_loading ? 'Loading...' : 'Not available'),
                  ),
                  _row('DEVICE ID', _device ?? '...', copy: _device != null),
                  if (since != null)
                    _row(
                      'ACTIVATED',
                      '${since.year}-${_two(since.month)}-${_two(since.day)} '
                          '${_two(since.hour)}:${_two(since.minute)}',
                    ),
                  _row('APP VERSION', AppConfig.version),
                  if (_info != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_info!, style: FapText.label),
                    ),
                  const Divider(color: FapColors.panelBorder),
                  const SizedBox(height: 8),
                  const Text(
                    'New tablet? Deactivate the license here (internet '
                    'needed), then enter the same code on the new device.',
                    style: FapText.label,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _deactivate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FapColors.amber,
                      side: const BorderSide(color: FapColors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.swap_horiz),
                    label: const Text(
                      'DEACTIVATE & TRANSFER LICENSE',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: FapText.label.copyWith(color: FapColors.red),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
