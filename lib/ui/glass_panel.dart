import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  final double? opacityOverride;


  final Color? accent;
  final double borderOpacity;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.radius = 16,
    this.opacityOverride,
    this.accent,
    this.borderOpacity = 0.18,
  });

  @override
  Widget build(BuildContext context) {
    final base = opacityOverride ?? 0.64;
    final a = accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Color.fromRGBO(14, 14, 18, base),
            border: Border.all(
              color: Color.fromRGBO(255, 255, 255, borderOpacity),
            ),
            gradient: a == null
                ? null
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                a.withOpacity(0.12),
                const Color(0x00000000),
                a.withOpacity(0.06),
              ],
            ),
            boxShadow: [
              const BoxShadow(
                blurRadius: 22,
                offset: Offset(0, 10),
                color: Color(0x44000000),
              ),
              if (a != null)
                BoxShadow(
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                  color: a.withOpacity(0.10),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
