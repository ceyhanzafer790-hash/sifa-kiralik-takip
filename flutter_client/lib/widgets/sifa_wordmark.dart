import 'package:flutter/material.dart';

import 'sifa_brand.dart';

class SifaWordmark extends StatelessWidget {
  final bool compact;
  final bool showSubtitle;
  final bool light;

  const SifaWordmark({
    super.key,
    this.compact = false,
    this.showSubtitle = true,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 29.0 : 44.0;
    final foreground = light ? Colors.white : SifaBrand.charcoal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 28 : 42,
                  height: 0.9,
                  letterSpacing: -3,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: compact ? 1 : 2,
                  right: compact ? 1 : 2,
                ),
                child: _PillarMark(
                  width: compact ? 9 : 13,
                  height: compact ? 28 : 42,
                  foreground: foreground,
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'FA',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 28 : 42,
                      height: 0.9,
                      letterSpacing: -2.8,
                    ),
                  ),
                  Positioned(
                    left: compact ? 3 : 5,
                    top: compact ? -1 : -2,
                    child: Container(
                      width: compact ? 23 : 35,
                      height: compact ? 4 : 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            SifaBrand.deepGold,
                            Color(0xFFF0CF68),
                            SifaBrand.deepGold,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: compact ? 4 : 6,
                    bottom: compact ? 2 : 3,
                    child: SifaBuildingMark(
                      size: compact ? 12 : 18,
                      gold: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: compact ? 1 : 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 15 : 26,
                height: 1,
                color: SifaBrand.gold,
              ),
              SizedBox(width: compact ? 5 : 8),
              Text(
                'İNŞAAT',
                style: TextStyle(
                  color: SifaBrand.deepGold,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 7.5 : 11,
                  letterSpacing: compact ? 3.1 : 5.0,
                ),
              ),
              SizedBox(width: compact ? 5 : 8),
              Container(
                width: compact ? 15 : 26,
                height: 1,
                color: SifaBrand.gold,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PillarMark extends StatelessWidget {
  final double width;
  final double height;
  final Color foreground;

  const _PillarMark({
    required this.width,
    required this.height,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: width * 0.72,
              height: height * 0.16,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SifaBrand.deepGold,
                    Color(0xFFF0CF68),
                    SifaBrand.deepGold,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: height * 0.16,
            child: Container(
              width: width,
              height: height * 0.11,
              color: foreground,
            ),
          ),
          Positioned(
            top: height * 0.27,
            bottom: height * 0.08,
            child: Row(
              children: [
                Container(width: width * 0.22, color: foreground),
                SizedBox(width: width * 0.12),
                Container(width: width * 0.22, color: foreground),
                SizedBox(width: width * 0.12),
                Container(width: width * 0.22, color: foreground),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: width,
              height: height * 0.08,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
