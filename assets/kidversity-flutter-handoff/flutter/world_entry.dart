import 'package:flutter/material.dart';
import 'kidversity_theme.dart';

/// Pass real catalog data and an existing route callback; no hard-coded service state.
/// compact is determined by the parent CONTENT layout, not the card's own width.
class WorldEntry extends StatelessWidget {
  const WorldEntry({
    super.key,
    required this.title,
    required this.description,
    required this.assetPath,
    required this.onTap,
    this.compact = false,
  });
  final String title;
  final String description;
  final String assetPath;
  final VoidCallback onTap;
  final bool compact;

  Widget _art() => Image.asset(
        assetPath,
        fit: compact ? BoxFit.contain : BoxFit.cover,
        alignment: Alignment.center,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: KvColors.primaryTint,
          child: Center(child: Icon(Icons.auto_stories_outlined, color: KvColors.primary)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: text.titleMedium),
        const SizedBox(height: 6),
        Text(description, style: text.bodyMedium?.copyWith(color: KvColors.secondaryText)),
      ],
    );
    return Material(
      color: KvColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: KvColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: compact
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 80, height: 80, child: _art()),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: copy),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: KvColors.secondaryText),
                ]),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 140, child: _art()),
                  Padding(padding: const EdgeInsets.all(20), child: copy),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.arrow_forward, color: KvColors.primary),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
