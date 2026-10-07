import 'package:flutter/material.dart';

import '../theme/fap_theme.dart';

/// Important notice shown after the open code, every time the app starts,
/// before the panel opens.
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key, required this.onAgree});

  final VoidCallback onAgree;

  static const _points = [
    (
      'NOT AN OFFICIALLY CERTIFIED FTD',
      'This application is a classroom supplement and is NOT certified by '
          'Airbus, FAA, EASA, CAAP, or any civil aviation authority for '
          'official type-rating or flight training credits.',
    ),
    (
      'NO AFFILIATION',
      '"A320" and related aircraft trademarks belong to Airbus. Overdrive '
          'Interactive is an independent entity with no official endorsement '
          'or affiliation with Airbus.',
    ),
    (
      'ACCURACY & LIABILITY',
      'While modeled for realistic interaction, operational variances may '
          'exist. This software must NOT be used for real-world aircraft '
          'operation, checklist validation, or actual emergency procedures. '
          'Overdrive Interactive assumes no liability for misuse.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FapColors.statusBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                decoration: BoxDecoration(
                  color: FapColors.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: FapColors.amber, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: FapColors.amber,
                          size: 34,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'IMPORTANT NOTICE & DISCLAIMER',
                            style: TextStyle(
                              color: FapColors.amber,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'This software (A320 FAP Simulator) is developed by '
                      'Overdrive Interactive for academic, familiarization, and '
                      'educational training purposes only.',
                      style: TextStyle(
                        color: FapColors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (var i = 0; i < _points.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${i + 1}.',
                                style: const TextStyle(
                                  color: FapColors.cyan,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${_points[i].$1}: ',
                                      style: const TextStyle(
                                        color: FapColors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(text: _points[i].$2),
                                  ],
                                ),
                                style: const TextStyle(
                                  color: FapColors.textDim,
                                  fontSize: 14.5,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'By clicking "I AGREE & CONTINUE", you acknowledge and '
                      'accept these terms.',
                      style: TextStyle(
                        color: FapColors.white,
                        fontSize: 14.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: onAgree,
                      style: FilledButton.styleFrom(
                        backgroundColor: FapColors.activeGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 15,
                        ),
                      ),
                      child: const Text('I AGREE & CONTINUE'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
