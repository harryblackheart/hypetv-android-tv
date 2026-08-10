import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hypetv/core/theme/app_theme.dart';

class CatalogueStateView extends StatelessWidget {
  const CatalogueStateView({
    required this.title,
    required this.message,
    super.key,
    this.onRetry,
    this.icon = Icons.movie_filter_outlined,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 430;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 24 : 48,
              vertical: compact ? 14 : 32,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - (compact ? 28 : 64),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: compact ? 38 : 62, color: AppColors.red),
                      SizedBox(height: compact ? 10 : 22),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: compact
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineMedium,
                      ),
                      SizedBox(height: compact ? 6 : 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: compact ? 14 : 18,
                        ),
                      ),
                      if (onRetry != null) ...[
                        SizedBox(height: compact ? 14 : 28),
                        FilledButton.icon(
                          autofocus: true,
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CatalogueLoadingView extends StatelessWidget {
  const CatalogueLoadingView({super.key, this.label = 'Loading HypeTV…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 46,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 22),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
