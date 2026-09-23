import 'package:flutter/material.dart';

enum AppStatusTone {
  success,
  warning,
  danger,
  info,
  neutral,
}

class StatusPill extends StatelessWidget {
  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final bool compact;

  const StatusPill({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palette(context, tone);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 13 : 15, color: palette.foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: palette.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  static _StatusPalette _palette(
    BuildContext context,
    AppStatusTone tone,
  ) {
    return switch (tone) {
      AppStatusTone.success => const _StatusPalette(
          background: Color(0xFFEAF6EF),
          foreground: Color(0xFF246B45),
          border: Color(0xFFCBE7D6),
        ),
      AppStatusTone.warning => const _StatusPalette(
          background: Color(0xFFFFF4E5),
          foreground: Color(0xFF9A5D00),
          border: Color(0xFFF1D8AF),
        ),
      AppStatusTone.danger => const _StatusPalette(
          background: Color(0xFFFFECEC),
          foreground: Color(0xFFA53C3C),
          border: Color(0xFFF0CACA),
        ),
      AppStatusTone.info => const _StatusPalette(
          background: Color(0xFFEAF1FA),
          foreground: Color(0xFF315F91),
          border: Color(0xFFCCDDF0),
        ),
      AppStatusTone.neutral => _StatusPalette(
          background:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          foreground: Theme.of(context).colorScheme.onSurfaceVariant,
          border: Theme.of(context).dividerColor,
        ),
    };
  }
}

class _StatusPalette {
  final Color background;
  final Color foreground;
  final Color border;

  const _StatusPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });
}
