import 'package:flutter/material.dart';
import 'package:hypetv/core/theme/app_theme.dart';

class TvButton extends StatefulWidget {
  const TvButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.autofocus = false,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;
  final bool primary;

  @override
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _focused ? 1.06 : 1,
      duration: const Duration(milliseconds: 140),
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (value) => setState(() => _focused = value),
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon ?? Icons.play_arrow_rounded),
          label: Text(widget.label),
          style: FilledButton.styleFrom(
            backgroundColor: widget.primary ? AppColors.red : Colors.white,
            foregroundColor: widget.primary ? Colors.white : Colors.black,
            side: _focused
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
