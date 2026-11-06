import 'package:flutter/material.dart';

import '../utils/theme.dart';

class GoalCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String progressText; // e.g. "3 / 4 workouts"
  final double progress; // 0..1
  final VoidCallback onEdit;

  const GoalCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.progressText,
    required this.progress,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final done = progress >= 1;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (done) Icon(Icons.check_circle_rounded, color: color),
              IconButton(
                tooltip: 'Edit $title',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: context.borderColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(progressText, style: TextStyle(fontSize: 12, color: context.muted)),
        ],
      ),
    );
  }
}
