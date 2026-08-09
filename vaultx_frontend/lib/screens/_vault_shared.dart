/// _vault_shared.dart
/// Shared UI components used by LoginScreen and RegisterScreen.
/// Place this file at:  lib/screens/_vault_shared.dart
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OUTER BACKGROUND — deep dark base, no gradient (vault objects provide depth)
// ─────────────────────────────────────────────────────────────────────────────
class VaultBackground extends StatelessWidget {
  const VaultBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Same gradient as VaultCard, so the whole window reads as one
        // continuous surface — no separate darker "void" around the form.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E2340),
            Color(0xFF112B4E),
            Color(0xFF0C1E36),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  VAULT SCENE PAINTER — floating vault objects (locks, vaults, keys, shields)
//  This replaces VaultParticlePainter and provides the entire background scene.
// ─────────────────────────────────────────────────────────────────────────────
class VaultScenePainter extends CustomPainter {
  final double t; // 0..1 animation value (repeating)
  VaultScenePainter(this.t);

  // Each object: [seedX, seedY, scale, phaseOffset, type(0=lock,1=vault,2=key,3=shield,4=lockbody)]
  static const List<List<double>> _objects = [
    [0.08, 0.12, 1.1, 0.0, 0],
    [0.82, 0.08, 0.75, 1.2, 1],
    [0.55, 0.88, 0.9, 2.1, 2],
    [0.18, 0.75, 0.65, 0.7, 3],
    [0.92, 0.55, 0.8, 3.3, 0],
    [0.35, 0.18, 0.6, 1.8, 4],
    [0.70, 0.35, 1.0, 0.5, 1],
    [0.12, 0.45, 0.55, 2.7, 2],
    [0.60, 0.60, 0.7, 4.1, 3],
    [0.88, 0.82, 0.85, 1.5, 0],
    [0.42, 0.72, 0.65, 3.0, 4],
    [0.25, 0.38, 0.5, 0.3, 2],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _objects.length; i++) {
      final obj = _objects[i];
      final phase = obj[3];
      final scale = obj[4 == 1 ? 2 : 2]; // use obj[2]
      final objScale = obj[2];
      final type = obj[4].toInt();

      // Floating drift
      final driftX = math.sin(t * 2 * math.pi * 0.5 + phase) * 0.025;
      final driftY = math.cos(t * 2 * math.pi * 0.4 + phase) * 0.02;
      final cx = (obj[0] + driftX) * size.width;
      final cy = (obj[1] + driftY) * size.height;

      // Slow rotation for some objects
      final rotation = (type == 2 || type == 4)
          ? t * 2 * math.pi * 0.15 + phase
          : math.sin(t * math.pi * 0.3 + phase) * 0.18;

      // Pulse opacity
      final opacity = (0.06 + 0.035 * math.sin(t * 2 * math.pi * 0.6 + phase))
          .clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotation);
      canvas.scale(objScale * 0.95);

      switch (type) {
        case 0:
          _drawLock(canvas, opacity);
          break;
        case 1:
          _drawVaultDoor(canvas, opacity);
          break;
        case 2:
          _drawKey(canvas, opacity);
          break;
        case 3:
          _drawShield(canvas, opacity);
          break;
        case 4:
          _drawHexLock(canvas, opacity);
          break;
      }

      canvas.restore();
    }
  }

  void _drawLock(Canvas canvas, double opacity) {
    final strokePaint = Paint()
      ..color = const Color(0xFF2E75B6).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF58A6FF).withOpacity(opacity * 0.12)
      ..style = PaintingStyle.fill;

    // Lock body
    final bodyRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -6, 36, 28), const Radius.circular(6));
    canvas.drawRRect(bodyRect, fillPaint);
    canvas.drawRRect(bodyRect, strokePaint);

    // Shackle (arc)
    final shacklePaint = Paint()
      ..color = const Color(0xFF58A6FF).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final shacklePath = Path()
      ..moveTo(-10, -6)
      ..lineTo(-10, -18)
      ..arcToPoint(const Offset(10, -18),
          radius: const Radius.circular(10), clockwise: false)
      ..lineTo(10, -6);
    canvas.drawPath(shacklePath, shacklePaint);

    // Keyhole
    canvas.drawCircle(Offset.zero, 5, strokePaint..strokeWidth = 1.5);
    final keyholePath = Path()
      ..moveTo(-2.5, 3)
      ..lineTo(2.5, 3)
      ..lineTo(1.5, 12)
      ..lineTo(-1.5, 12)
      ..close();
    canvas.drawPath(keyholePath, strokePaint..strokeWidth = 1.2);
  }

  void _drawVaultDoor(Canvas canvas, double opacity) {
    final strokePaint = Paint()
      ..color = const Color(0xFF2E75B6).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final fillPaint = Paint()
      ..color = const Color(0xFF1A3A6A).withOpacity(opacity * 0.15)
      ..style = PaintingStyle.fill;

    // Outer frame
    final outerRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -26, 52, 52), const Radius.circular(6));
    canvas.drawRRect(outerRect, fillPaint);
    canvas.drawRRect(outerRect, strokePaint);

    // Inner door plate
    final innerRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -20, 36, 36), const Radius.circular(4));
    canvas.drawRRect(innerRect, strokePaint..strokeWidth = 1.2);

    // Dial rings
    canvas.drawCircle(Offset.zero, 12, strokePaint..strokeWidth = 1.4);
    canvas.drawCircle(Offset.zero, 7, strokePaint..strokeWidth = 1.0);
    canvas.drawCircle(Offset.zero, 2.5, strokePaint..strokeWidth = 1.0);

    // Dial tick marks (8 ticks)
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = Offset(math.cos(angle) * 13, math.sin(angle) * 13);
      final outer2 = Offset(math.cos(angle) * 17, math.sin(angle) * 17);
      canvas.drawLine(inner, outer2, strokePaint..strokeWidth = 1.0);
    }

    // Corner bolts
    const bolts = [
      Offset(-16, -16),
      Offset(16, -16),
      Offset(-16, 16),
      Offset(16, 16)
    ];
    for (final b in bolts) {
      canvas.drawCircle(b, 2.5, strokePaint..strokeWidth = 0.9);
    }

    // Hinge bar
    canvas.drawLine(const Offset(20, -14), const Offset(20, 14),
        strokePaint..strokeWidth = 3.5);
  }

  void _drawKey(Canvas canvas, double opacity) {
    final strokePaint = Paint()
      ..color = const Color(0xFF58A6FF).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Key bow (head ring)
    canvas.drawCircle(const Offset(-12, 0), 10, strokePaint);
    canvas.drawCircle(const Offset(-12, 0), 5, strokePaint..strokeWidth = 1.2);

    // Key blade (shaft)
    canvas.drawLine(const Offset(-2, 0), const Offset(22, 0),
        strokePaint..strokeWidth = 2.5);

    // Key teeth
    canvas.drawLine(
        const Offset(8, 0), const Offset(8, 6), strokePaint..strokeWidth = 2.0);
    canvas.drawLine(const Offset(14, 0), const Offset(14, 8),
        strokePaint..strokeWidth = 2.0);
    canvas.drawLine(const Offset(19, 0), const Offset(19, 5),
        strokePaint..strokeWidth = 2.0);
  }

  void _drawShield(Canvas canvas, double opacity) {
    final strokePaint = Paint()
      ..color = const Color(0xFF2E75B6).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF2E75B6).withOpacity(opacity * 0.1)
      ..style = PaintingStyle.fill;

    // Shield outline
    final shieldPath = Path()
      ..moveTo(0, -26)
      ..lineTo(20, -18)
      ..lineTo(20, 4)
      ..quadraticBezierTo(20, 22, 0, 30)
      ..quadraticBezierTo(-20, 22, -20, 4)
      ..lineTo(-20, -18)
      ..close();
    canvas.drawPath(shieldPath, fillPaint);
    canvas.drawPath(shieldPath, strokePaint);

    // Inner checkmark / lock icon
    final innerPath = Path()
      ..moveTo(-6, 2)
      ..lineTo(-1, 8)
      ..lineTo(7, -4);
    canvas.drawPath(innerPath, strokePaint..strokeWidth = 2.2);
  }

  void _drawHexLock(Canvas canvas, double opacity) {
    final strokePaint = Paint()
      ..color = const Color(0xFF58A6FF).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = const Color(0xFF1A3A6A).withOpacity(opacity * 0.12)
      ..style = PaintingStyle.fill;

    // Hexagon
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 6;
      final px = math.cos(angle) * 22.0;
      final py = math.sin(angle) * 22.0;
      if (i == 0)
        hexPath.moveTo(px, py);
      else
        hexPath.lineTo(px, py);
    }
    hexPath.close();
    canvas.drawPath(hexPath, fillPaint);
    canvas.drawPath(hexPath, strokePaint);

    // Mini lock inside
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-7, -2, 14, 11), const Radius.circular(2.5)),
        strokePaint..strokeWidth = 1.2);
    final shacklePath = Path()
      ..moveTo(-4, -2)
      ..lineTo(-4, -8)
      ..arcToPoint(const Offset(4, -8),
          radius: const Radius.circular(4), clockwise: false)
      ..lineTo(4, -2);
    canvas.drawPath(shacklePath, strokePaint..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(VaultScenePainter old) => old.t != t;
}

// Keep old name as alias so login/register don't need edits
typedef VaultParticlePainter = VaultScenePainter;

// ─────────────────────────────────────────────────────────────────────────────
//  INNER CARD — narrower (440px) to fit comfortably in 800×600 window
// ─────────────────────────────────────────────────────────────────────────────
class VaultCard extends StatelessWidget {
  final Widget child;
  const VaultCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E2340),
            Color(0xFF112B4E),
            Color(0xFF0C1E36),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFF1E4A7A).withOpacity(0.60),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 50,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF1A3A6A).withOpacity(0.25),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ICON BADGE — glowing lock / person icon
// ─────────────────────────────────────────────────────────────────────────────
class VaultIconBadge extends StatelessWidget {
  final IconData icon;
  final double glowValue; // 0..1
  const VaultIconBadge(
      {super.key, required this.icon, required this.glowValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E75B6).withOpacity(0.45 * glowValue),
            blurRadius: 22,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Icon(icon, size: 30, color: Colors.white),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TITLE + SUBTITLE
// ─────────────────────────────────────────────────────────────────────────────
class VaultTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const VaultTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFCAE8FF), Color(0xFF58A6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF5A7A9A)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────
class VaultTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;

  const VaultTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.onToggleObscure,
    this.onSubmitted,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      cursorColor: const Color(0xFF58A6FF),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6E8FAB), fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF2A3A4A), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0D1F30).withOpacity(0.6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: const Color(0xFF1E3A5A).withOpacity(0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2E75B6), width: 1.5),
        ),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF4A7A9B), size: 17),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF4A7A9B),
                  size: 17,
                ),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GRADIENT BUTTON (filled or outlined)
// ─────────────────────────────────────────────────────────────────────────────
class VaultGradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final List<Color> colors;
  final List<Color> hoverColors;
  final Color pressColor;
  final double height;
  final bool outlined;
  final Color? outlineColor;

  const VaultGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.colors,
    required this.hoverColors,
    required this.pressColor,
    this.height = 42,
    this.outlined = false,
    this.outlineColor,
  });

  @override
  State<VaultGradientButton> createState() => _VaultGradientButtonState();
}

class _VaultGradientButtonState extends State<VaultGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  bool _hovering = false;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _hovering = true);
    _ctrl.forward();
  }

  void _onExit(_) {
    setState(() {
      _hovering = false;
      _pressing = false;
    });
    _ctrl.reverse();
  }

  void _onTapDown(_) => setState(() => _pressing = true);
  void _onTapUp(_) => setState(() => _pressing = false);
  void _onTapCancel() => setState(() => _pressing = false);

  @override
  Widget build(BuildContext context) {
    final colors = _pressing
        ? [widget.pressColor, widget.pressColor]
        : (_hovering ? widget.hoverColors : widget.colors);

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.scale(
            scale: _scale.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              height: widget.height,
              decoration: BoxDecoration(
                gradient: widget.outlined
                    ? null
                    : LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: widget.outlined
                    ? Border.all(
                        color: _pressing
                            ? widget.pressColor
                            : (_hovering
                                ? widget.hoverColors.first
                                : (widget.outlineColor ?? widget.colors.first)),
                        width: 1.5,
                      )
                    : null,
                boxShadow: !widget.outlined && _hovering
                    ? [
                        BoxShadow(
                          color: colors.first.withOpacity(0.40 * _glow.value),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEXT LINK
// ─────────────────────────────────────────────────────────────────────────────
class VaultTextLink extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const VaultTextLink(
      {super.key, required this.label, required this.onPressed});

  @override
  State<VaultTextLink> createState() => _VaultTextLinkState();
}

class _VaultTextLinkState extends State<VaultTextLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 130),
            style: TextStyle(
              color:
                  _hovering ? const Color(0xFF8EC8FF) : const Color(0xFF58A6FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration:
                  _hovering ? TextDecoration.underline : TextDecoration.none,
              decorationColor: const Color(0xFF58A6FF),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR BOX
// ─────────────────────────────────────────────────────────────────────────────
class VaultErrorBox extends StatelessWidget {
  final String message;
  const VaultErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  THIN GRADIENT DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class VaultDivider extends StatelessWidget {
  const VaultDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF1E3A5A).withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}