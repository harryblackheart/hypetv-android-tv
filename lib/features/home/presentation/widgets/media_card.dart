import 'package:flutter/material.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/widgets/tv_action.dart';

class MediaCard extends StatefulWidget {
  const MediaCard({
    required this.item,
    required this.width,
    required this.onPressed,
    super.key,
    this.autofocus = false,
  });

  final ContentItem item;
  final double width;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _focused = false;

  void _handleFocus(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: .5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.item.title}, ${widget.item.subtitle}',
      child: AnimatedScale(
        scale: _focused ? 1.06 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Focus(
          autofocus: widget.autofocus,
          onKeyEvent: (_, event) => activateOnTvKey(event, widget.onPressed),
          onFocusChange: _handleFocus,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: widget.width,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _focused ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: _focused
                    ? const [
                        BoxShadow(
                          color: Colors.black87,
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.item.imageUrl.isNotEmpty)
                    Image.network(
                      widget.item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _ArtworkFallback(),
                    )
                  else
                    const _ArtworkFallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .48, 1],
                        colors: [
                          Colors.transparent,
                          Color(0x22000000),
                          Color(0xEE000000),
                        ],
                      ),
                    ),
                  ),
                  if (widget.item.badge case final badge?)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: widget.item.subtitle.isNotEmpty ? 30 : 14,
                    child: Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (widget.item.subtitle.isNotEmpty)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 10,
                      child: Text(
                        widget.item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (widget.item.progress case final progress?)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: AppColors.red,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceRaised,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 48,
          color: Colors.white38,
        ),
      ),
    );
  }
}
