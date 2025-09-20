import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DPadSquare extends StatelessWidget {
  final ValueChanged<bool> onUpChanged;
  final ValueChanged<bool> onDownChanged;
  final ValueChanged<bool> onLeftChanged;
  final ValueChanged<bool> onRightChanged;
  final double uiScale;
  final double side;

  const DPadSquare({
    super.key,
    required this.onUpChanged,
    required this.onDownChanged,
    required this.onLeftChanged,
    required this.onRightChanged,
    required this.uiScale,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    final s = side;
    final pad = (10.0 * uiScale).clamp(8.0, 12.0);

    return SizedBox(
      width: s,
      height: s,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x26111118),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          padding: EdgeInsets.all(pad),
          child: LayoutBuilder(
            builder: (context, c) {
              final cell = min(c.maxWidth, c.maxHeight) / 3.0;

              Widget gap() => SizedBox(width: cell, height: cell);

              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: gap()),
                        Expanded(
                          child: _HoldCell(
                            icon: Icons.keyboard_arrow_up,
                            onChanged: onUpChanged,
                            uiScale: uiScale,
                          ),
                        ),
                        Expanded(child: gap()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _HoldCell(
                            icon: Icons.keyboard_arrow_left,
                            onChanged: onLeftChanged,
                            uiScale: uiScale,
                          ),
                        ),
                        Expanded(child: gap()),
                        Expanded(
                          child: _HoldCell(
                            icon: Icons.keyboard_arrow_right,
                            onChanged: onRightChanged,
                            uiScale: uiScale,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: gap()),
                        Expanded(
                          child: _HoldCell(
                            icon: Icons.keyboard_arrow_down,
                            onChanged: onDownChanged,
                            uiScale: uiScale,
                          ),
                        ),
                        Expanded(child: gap()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HoldCell extends StatefulWidget {
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final double uiScale;

  const _HoldCell({
    required this.icon,
    required this.onChanged,
    required this.uiScale,
  });

  @override
  State<_HoldCell> createState() => _HoldCellState();
}

class _HoldCellState extends State<_HoldCell> {
  bool pressed = false;

  void _set(bool v) {
    if (!mounted) return;
    if (pressed == v) return;
    setState(() => pressed = v);
    widget.onChanged(v);
    if (v) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = (22.0 * widget.uiScale).clamp(18.0, 26.0);

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: EdgeInsets.all((5.0 * widget.uiScale).clamp(3.0, 6.0)),
        decoration: BoxDecoration(
          color: pressed ? const Color(0x44FFFFFF) : const Color(0x2217171F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        alignment: Alignment.center,
        child: Icon(widget.icon, size: iconSize, color: const Color(0xFFE6E6F0)),
      ),
    );
  }
}
