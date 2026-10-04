import 'package:flutter/material.dart';

import '../theme/fap_theme.dart';

/// Official AISAT Aviation logo (wings with globe "A").
class AisatLogo extends StatelessWidget {
  const AisatLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: FapColors.aisatCyan.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: FapColors.aisatCyan.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/aisat_logo.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
