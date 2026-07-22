// lib/widgets/sidebar_toggle.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SidebarToggleIcon extends StatefulWidget {
  final VoidCallback onTap;
  final bool isSidebarExpanded;

  const SidebarToggleIcon({
    super.key,
    required this.onTap,
    required this.isSidebarExpanded,
  });

  @override
  State<SidebarToggleIcon> createState() => _SidebarToggleIconState();
}

class _SidebarToggleIconState extends State<SidebarToggleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _colorController;
  bool _hovering = false;

  static const List<Color> _rainbowCycle = [
    Color(0xFF00FF88),
    Color(0xFF88FF00),
    Color(0xFFFFFF00),
    Color(0xFFFFAA00),
    Color(0xFFFF4400),
    Color(0xFFFF0088),
    Color(0xFFAA00FF),
    Color(0xFF4400FF),
    Color(0xFF0088FF),
    Color(0xFF00CCFF),
    Color(0xFF00FFCC),
    Color(0xFF00FF88),
  ];

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _colorController,
          builder: (context, child) {
            return Transform.scale(
              scale: _hovering ? 1.05 : 1.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rainbow ring painter
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RainbowRingPainter(
                        t: _colorController.value,
                        colors: _rainbowCycle,
                        opacity: _hovering ? 1.0 : 0.20,
                        glowRadius: _hovering ? 12.0 : 5.0,
                        borderRadius: 8,
                      ),
                    ),
                  ),
                  // Button body - FIXED: Constrained width to prevent overflow
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      maxWidth: 36,
                      minHeight: 36,
                      maxHeight: 36,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _hovering
                              ? [
                                  const Color(0xFF0E2340),
                                  const Color(0xFF0C1E36),
                                ]
                              : [
                                  const Color(0xFF091828),
                                  const Color(0xFF071320),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _hovering
                            ? [
                                BoxShadow(
                                  color: _rainbowColorAt(_colorController.value)
                                      .withOpacity(0.40),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hamburger icon (always visible)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CustomPaint(
                              painter: _DocumentIconPainter(
                                color: _hovering
                                    ? _rainbowColorAt(_colorController.value)
                                    : const Color(0xFF4A7A9B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Chevron icon
                          Icon(
                            widget.isSidebarExpanded
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                            size: 14,
                            color: _hovering
                                ? _rainbowColorAt(_colorController.value)
                                : const Color(0xFF4A7A9B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _rainbowColorAt(double t) {
    final count = _rainbowCycle.length - 1;
    final scaled = t * count;
    final index = scaled.floor().clamp(0, count - 1);
    final frac = scaled - index;
    return Color.lerp(_rainbowCycle[index], _rainbowCycle[index + 1], frac)!;
  }
}

class _RainbowRingPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final double opacity;
  final double glowRadius;
  final double borderRadius;

  _RainbowRingPainter({
    required this.t,
    required this.colors,
    required this.opacity,
    required this.glowRadius,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(borderRadius));

    final sweepAngle = t * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + 2 * math.pi,
        colors: colors.map((c) => c.withOpacity(opacity)).toList(),
        stops: List.generate(
            colors.length, (i) => i / (colors.length - 1).toDouble()),
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowRadius
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.5)
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + 2 * math.pi,
        colors: colors.map((c) => c.withOpacity(opacity * 0.35)).toList(),
        stops: List.generate(
            colors.length, (i) => i / (colors.length - 1).toDouble()),
      ).createShader(rect);

    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(_RainbowRingPainter old) =>
      old.t != t || old.opacity != opacity;
}

class _DocumentIconPainter extends CustomPainter {
  final Color color;
  _DocumentIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final startX = size.width * 0.2;
    final endX = size.width * 0.8;
    final lineHeight = size.height / 5;

    for (int i = 0; i < 3; i++) {
      final y = lineHeight * (i * 1.5 + 0.8);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DocumentIconPainter old) => old.color != color;
}
