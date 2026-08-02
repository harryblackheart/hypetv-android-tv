import 'package:flutter/material.dart';
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fontSize = 42, this.showTagline = false});
  final double fontSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: showTagline ? 'Hype TV. ${AppConstants.slogan}' : 'Hype TV',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('HYPE', style: _wordStyle),
              SizedBox(width: fontSize * .13),
              Text('TV', style: _wordStyle),
            ],
          ),
          if (showTagline) ...[
            SizedBox(height: fontSize * .16),
            Text(
              AppConstants.slogan.toUpperCase(),
              style: TextStyle(
                color: Colors.white60,
                fontSize: (fontSize * .2).clamp(9, 16),
                fontWeight: FontWeight.w600,
                letterSpacing: fontSize * .025,
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle get _wordStyle => TextStyle(
    color: AppColors.red,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    letterSpacing: -2,
    height: 1,
    shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
  );
}
