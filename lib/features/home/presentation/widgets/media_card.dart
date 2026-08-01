import 'package:flutter/material.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/domain/content_item.dart';

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
    final height = widget.width * .58;
    return Semantics(
      button: true,
      label: '${widget.item.title}, ${widget.item.subtitle}',
      child: AnimatedScale(
        scale: _focused ? 1.08 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Focus(
          autofocus: widget.autofocus,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: height,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: AppColors.surfaceRaised,
                                child: Icon(
                                  Icons.movie_outlined,
                                  size: 48,
                                  color: Colors.white38,
                                ),
                              ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
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
                          bottom: 12,
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
                      ],
                    ),
                  ),
                  if (widget.item.progress case final progress?)
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: AppColors.red,
                      backgroundColor: Colors.white12,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Text(
                      widget.item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
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
