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
    setState(() => _code += digit);
  }

  void _remove() {
    if (_code.isEmpty) return;
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
      body: Focus(
        onKeyEvent: _onKeyEvent,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(72, 48, 48, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandLogo(),
                    const SizedBox(height: 48),
                    Text(
                      'Activate your TV',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter the 5-digit code shown in your HypeTV account.',
                      style: TextStyle(color: AppColors.muted, fontSize: 20),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: List.generate(
                        AppConstants.activationCodeLength,
                        (index) => _CodeBox(
                          value: index < _code.length ? _code[index] : '',
                          active: index == _code.length,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: error == null
                          ? const SizedBox(height: 28)
                          : Text(
                              error,
                              key: ValueKey(error),
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 17,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.65,
                          children: [
                            for (var number = 1; number <= 9; number++)
                              _KeypadButton(
                                label: '$number',
                                onPressed: busy
                                    ? null
                                    : () => _append('$number'),
                              ),
                            _KeypadButton(
                              icon: Icons.backspace_outlined,
                              onPressed: busy ? null : _remove,
                            ),
                            _KeypadButton(
                              label: '0',
                              onPressed: busy ? null : () => _append('0'),
                            ),
                            _KeypadButton(
                              icon: busy
                                  ? Icons.hourglass_top_rounded
                                  : Icons.check_rounded,
                              primary: true,
                              onPressed:
                                  busy ||
                                      _code.length !=
                                          AppConstants.activationCodeLength
                                  ? null
                                  : _submit,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Use your remote to enter the code',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.value, required this.active});
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 76,
      height: 88,
      margin: const EdgeInsets.only(right: 14),
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
        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700),
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
  });
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final bool primary;

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
            ? Icon(widget.icon, size: 28)
            : Text(
                widget.label!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
