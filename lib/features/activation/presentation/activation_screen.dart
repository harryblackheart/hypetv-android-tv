import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/activation/presentation/activation_controller.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  var _code = '';

  void _append(String digit) {
    if (_code.length >= AppConstants.activationCodeLength) return;
    ref.read(activationControllerProvider.notifier).clearError();
    setState(() => _code += digit);
  }

  void _remove() {
    if (_code.isEmpty) return;
    ref.read(activationControllerProvider.notifier).clearError();
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    if (_code.length != AppConstants.activationCodeLength) return;
    final success = await ref
        .read(activationControllerProvider.notifier)
        .activate(_code);
    if (success && mounted) context.go('/home');
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final label = event.logicalKey.keyLabel;
    if (RegExp(r'^\d$').hasMatch(label)) {
      _append(label);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _remove();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        _code.length == AppConstants.activationCodeLength) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final activation = ref.watch(activationControllerProvider);
    final busy = activation.isLoading;
    final error = activation.hasError ? activation.error.toString() : null;

    return Scaffold(
      body: SafeArea(
        child: Focus(
          onKeyEvent: _onKeyEvent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 1200 || constraints.maxHeight < 700;
              return Row(
                children: [
                  Expanded(
                    flex: compact ? 5 : 6,
                    child: _ActivationIntro(
                      code: _code,
                      busy: busy,
                      error: error,
                      compact: compact,
                    ),
                  ),
                  Expanded(
                    flex: compact ? 5 : 4,
                    child: _ActivationKeypad(
                      compact: compact,
                      busy: busy,
                      codeLength: _code.length,
                      onDigit: _append,
                      onRemove: _remove,
                      onSubmit: _submit,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActivationIntro extends StatelessWidget {
  const _ActivationIntro({
    required this.code,
    required this.busy,
    required this.error,
    required this.compact,
  });

  final String code;
  final bool busy;
  final String? error;
  final bool compact;

  String get _status {
    if (busy) return 'Checking your activation code…';
    if (error != null) return 'Activation failed: $error';
    if (code.isEmpty) return 'Enter your 5-digit code';
    if (code.length < AppConstants.activationCodeLength) {
      return '${code.length} of ${AppConstants.activationCodeLength} digits entered';
    }
    return 'Code ready — select the tick to activate';
  }

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 28, vertical: 18)
        : const EdgeInsets.fromLTRB(72, 48, 48, 48);
    final statusColor = error != null ? AppColors.red : AppColors.muted;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = compact ? 8.0 : 14.0;
          final available =
              constraints.maxWidth -
              (gap * (AppConstants.activationCodeLength - 1));
          final boxWidth = (available / AppConstants.activationCodeLength)
              .clamp(40.0, compact ? 58.0 : 76.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandLogo(fontSize: compact ? 30 : 42),
              SizedBox(height: compact ? 16 : 48),
              Text(
                'Activate your TV',
                style: compact
                    ? Theme.of(context).textTheme.headlineLarge
                    : Theme.of(context).textTheme.displayLarge,
              ),
              SizedBox(height: compact ? 8 : 16),
              Text(
                'Enter the 5-digit code shown in your HypeTV account.',
                maxLines: compact ? 2 : null,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 15 : 20,
                ),
              ),
              SizedBox(height: compact ? 16 : 36),
              Row(
                children: [
                  for (
                    var index = 0;
                    index < AppConstants.activationCodeLength;
                    index++
                  ) ...[
                    if (index > 0) SizedBox(width: gap),
                    _CodeBox(
                      value: index < code.length ? code[index] : '',
                      active: index == code.length,
                      width: boxWidth,
                      compact: compact,
                    ),
                  ],
                ],
              ),
              SizedBox(height: compact ? 12 : 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(_status),
                  children: [
                    if (busy) ...[
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        _status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: compact ? 14 : 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivationKeypad extends StatelessWidget {
  const _ActivationKeypad({
    required this.compact,
    required this.busy,
    required this.codeLength,
    required this.onDigit,
    required this.onRemove,
    required this.onSubmit,
  });

  final bool compact;
  final bool busy;
  final int codeLength;
  final ValueChanged<String> onDigit;
  final VoidCallback onRemove;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final spacing = compact ? 8.0 : 12.0;
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.all(compact ? 18 : 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: compact ? 2.05 : 1.65,
                children: [
                  for (var number = 1; number <= 9; number++)
                    _KeypadButton(
                      label: '$number',
                      compact: compact,
                      onPressed: busy ? null : () => onDigit('$number'),
                    ),
                  _KeypadButton(
                    icon: Icons.backspace_outlined,
                    compact: compact,
                    onPressed: busy ? null : onRemove,
                  ),
                  _KeypadButton(
                    label: '0',
                    compact: compact,
                    onPressed: busy ? null : () => onDigit('0'),
                  ),
                  _KeypadButton(
                    icon: busy
                        ? Icons.hourglass_top_rounded
                        : Icons.check_rounded,
                    compact: compact,
                    primary: true,
                    onPressed:
                        busy || codeLength != AppConstants.activationCodeLength
                        ? null
                        : onSubmit,
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 24),
              Text(
                compact
                    ? 'Enter the code, then select ✓'
                    : 'Use your remote to enter the code',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.value,
    required this.active,
    required this.width,
    required this.compact,
  });
  final String value;
  final bool active;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: compact ? 60 : 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.red : Colors.white24,
          width: active ? 3 : 1,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: compact ? 30 : 42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _KeypadButton extends StatefulWidget {
  const _KeypadButton({
    required this.onPressed,
    this.label,
    this.icon,
    this.primary = false,
    this.compact = false,
  });
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final bool primary;
  final bool compact;

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: FilledButton(
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: widget.primary
              ? AppColors.red
              : AppColors.surfaceRaised,
          side: _focused
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: widget.icon != null
            ? Icon(widget.icon, size: widget.compact ? 22 : 28)
            : Text(
                widget.label!,
                style: TextStyle(
                  fontSize: widget.compact ? 20 : 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
