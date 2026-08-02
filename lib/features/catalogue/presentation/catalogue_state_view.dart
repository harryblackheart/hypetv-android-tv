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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 62, color: AppColors.red),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 18),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 28),
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
    );
  }
}

class CatalogueLoadingView extends StatelessWidget {
  const CatalogueLoadingView({super.key, this.label = 'Loading HypeTV…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
