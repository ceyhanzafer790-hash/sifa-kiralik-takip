import 'package:flutter/material.dart';

class SifaWordmark extends StatelessWidget {
  final bool compact;
  final bool showSubtitle;

  const SifaWordmark({
    super.key,
    this.compact = false,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ŞİFA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? 1.4 : 2.4,
                color: scheme.primary,
                height: 1,
              ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 3),
          Text(
            'İNŞAAT  •  KİRALIK TAKİP',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? 0.4 : 0.8,
                  color: const Color(0xFF9A7447),
                ),
          ),
        ],
      ],
    );
  }
}
