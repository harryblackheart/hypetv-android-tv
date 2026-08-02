import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/activation/presentation/activation_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _hypeOpacity;
  late final Animation<double> _tvOpacity;
  late final Animation<Offset> _tvSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _sceneOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _hypeOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.04, .30, curve: Curves.easeOut),
    );
    _tvOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.28, .50, curve: Curves.easeOut),
    );
    _tvSlide = Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(.27, .52, curve: Curves.easeOutCubic),
          ),
        );
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.52, .74, curve: Curves.easeOut),
    );
    _sceneOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 84),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
    ]).animate(_controller);
    _continue();
  }

  Future<void> _continue() async {
    final activationFuture = ref.read(activationControllerProvider.future);
    await _controller.forward();
    final activated = await activationFuture;
    if (!mounted) return;
    context.go(activated ? '/home' : '/activate');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = (MediaQuery.sizeOf(context).width * .11).clamp(
      78.0,
      160.0,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: 'Hype TV. ${AppConstants.slogan}',
        child: FadeTransition(
          opacity: _sceneOpacity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    FadeTransition(
                      opacity: _hypeOpacity,
                      child: _LogoWord('HYPE', fontSize: logoSize),
                    ),
                    SizedBox(width: logoSize * .10),
                    ClipRect(
                      child: FadeTransition(
                        opacity: _tvOpacity,
                        child: SlideTransition(
                          position: _tvSlide,
                          child: _LogoWord('TV', fontSize: logoSize),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: logoSize * .35),
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    AppConstants.slogan.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: (logoSize * .2).clamp(16, 30),
                      fontWeight: FontWeight.w600,
                      letterSpacing: logoSize * .045,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoWord extends StatelessWidget {
  const _LogoWord(this.text, {required this.fontSize});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.red,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: .9,
        letterSpacing: -fontSize * .045,
      ),
    );
  }
}
