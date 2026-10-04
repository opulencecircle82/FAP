import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme/fap_theme.dart';
import '../widgets/aisat_logo.dart';
import 'fap_simulator_screen.dart';

/// AISAT Aviation app download hub.
class LandingPageScreen extends StatelessWidget {
  const LandingPageScreen({super.key});

  static const route = '/hub';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FapColors.landingBg,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _RadarBackdrop())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final gutter = wide ? 48.0 : 16.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _TopBar(),
                          SizedBox(height: wide ? 48 : 28),
                          if (wide)
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: _Hero(wide: true)),
                                SizedBox(width: 48),
                                Expanded(flex: 4, child: _DownloadCard()),
                              ],
                            )
                          else ...const [
                            _Hero(wide: false),
                            SizedBox(height: 28),
                            _DownloadCard(),
                          ],
                          SizedBox(height: wide ? 56 : 32),
                          _Features(wide: wide),
                          const SizedBox(height: 40),
                          const _Footer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AisatLogo(size: 44),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'AISAT AVIATION',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FapColors.aisatCyan.withValues(alpha: 0.6),
            ),
          ),
          child: const Text(
            'v${AppConfig.version}',
            style: TextStyle(
              fontFamily: FapText.mono,
              color: FapColors.aisatCyan,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        AisatLogo(size: wide ? 150 : 120),
        const SizedBox(height: 28),
        Text(
          'AISAT Airbus A320 FAP\nMobile & Tablet Simulator',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 44 : 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Train on a full replica of the Airbus A320 CIDS Flight Attendant '
          'Panel: cabin lighting, doors and slides, PRAM announcements, '
          'water/waste, lavatory smoke and evacuation signalling.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: const TextStyle(
            color: FapColors.aisatSilver,
            fontSize: 17,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _PrimaryButton(
              icon: Icons.android,
              label: 'DOWNLOAD APK',
              onTap: () => _downloadApk(context),
            ),
            _OutlineButton(
              icon: Icons.touch_app_outlined,
              label: 'LAUNCH WEB SIMULATOR',
              onTap: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  nav.pushNamed(FapSimulatorScreen.route);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _downloadApk(BuildContext context) async {
  const url = AppConfig.apkUrl;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_self',
  );
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open download link: $url')),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xCC12212F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FapColors.aisatCyan.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: FapColors.aisatCyan.withValues(alpha: 0.12),
            blurRadius: 40,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'SCAN TO INSTALL ON TABLET',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: AppConfig.apkUrl,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0A1520),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0A1520),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            AppConfig.apkFileName,
            style: TextStyle(
              fontFamily: FapText.mono,
              color: FapColors.aisatCyan,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Android 7.0+  -  landscape tablet recommended',
            textAlign: TextAlign.center,
            style: TextStyle(color: FapColors.aisatSilver, fontSize: 12),
          ),
          const SizedBox(height: 20),
          const _Steps(),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Scan the QR code or tap DOWNLOAD APK.',
      'Allow "Install unknown apps" for your browser when asked.',
      'Open AISAT FAP and hold the tablet in landscape.',
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: FapColors.aisatCyan,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: const TextStyle(
                      color: FapColors.aisatSilver,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.cloud_off_outlined,
        'Offline Ready',
        'No SQL / database needed. Everything runs on the tablet, even with '
            'no internet in the classroom.',
      ),
      (
        Icons.memory,
        'Authentic A320 CIDS Logic',
        'BRT / DIM 1 / DIM 2 lighting, slide arming, EVAC CMD and RESET, '
            'SMOKE RESET and real Airbus chimes.',
      ),
      (
        Icons.school_outlined,
        'Flight Attendant Training Drills',
        'Arm / disarm and cross-check, lavatory smoke, evacuation, PRAM '
            'announcements and CIDS fault scenarios.',
      ),
    ];
    final cards = [
      for (final f in items) _FeatureCard(icon: f.$1, title: f.$2, body: f.$3),
    ];
    if (!wide) {
      return Column(
        children: [
          for (final c in cards)
            Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 18),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xAA12212F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223649)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FapColors.aisatCyan, size: 30),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: FapColors.aisatSilver,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'For AISAT Aviation College cabin crew training only. Not for '
      'operational use. Always follow your airline cabin crew manual.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF5E7184), fontSize: 12),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: FapColors.aisatCyan,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: FapColors.aisatSilver),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Faint concentric rings echoing the AISAT logo backdrop.
class _RadarBackdrop extends CustomPainter {
  const _RadarBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.18);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = FapColors.aisatCyan.withValues(alpha: 0.07);
    for (var r = 120.0; r < size.longestSide * 1.2; r += 110) {
      canvas.drawCircle(center, r, ring);
    }
    canvas.drawCircle(
      center,
      260,
      Paint()
        ..shader = RadialGradient(
          colors: [
            FapColors.aisatCyan.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 260)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
