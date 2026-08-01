import 'package:flutter/material.dart';
import 'package:hypetv/core/theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fontSize = 42});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hype TV',
      child: Text(
        'HYPE',
        style: TextStyle(
          color: AppColors.red,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
          height: 1,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
        ),
      ),
    );
  }
}
