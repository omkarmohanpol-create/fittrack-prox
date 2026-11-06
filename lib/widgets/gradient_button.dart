import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Primary button from DESIGN.md: 56px high, 16px radius, indigo->violet gradient.
class GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: enabled ? widget.onPressed : null,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                child: Center(
                  child: widget.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
