import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import '../utils/theme.dart';

/// Animated circular progress (8px stroke, 600ms ease-in-out per DESIGN.md).
class WaterRing extends StatelessWidget {
  final int currentMl;
  final int goalMl;
  final double size;

  const WaterRing({
    super.key,
    required this.currentMl,
    required this.goalMl,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goalMl <= 0 ? 0.0 : (currentMl / goalMl).clamp(0.0, 1.0);
    final percent = goalMl <= 0 ? 0 : (currentMl / goalMl * 100).round();

    return Semantics(
      label:
          'Water intake ${Formatters.volumeMl(currentMl)} of ${Formatters.volumeMl(goalMl)}',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          builder: (context, value, _) {
            return CustomPaint(
              painter: _RingPainter(
                progress: value,
                track: context.borderColor,
                color: AppColors.water,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.volumeMl(currentMl)} / ${Formatters.volumeMl(goalMl)}',
                      style: TextStyle(fontSize: 14, color: context.muted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}
