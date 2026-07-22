import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../main.dart' show shrinkToLoginWindow;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Hexagon grid + particle drift
  late AnimationController _hexCtrl;
  // Rotating cipher ring
  late AnimationController _cipherCtrl;
  // Shield unlock animation
  late AnimationController _shieldCtrl;
  late Animation<double> _shieldScale;
  late Animation<double> _shieldGlow;
  // Title reveal
  late AnimationController _titleCtrl;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  // Tagline + version reveal
  late AnimationController _tagCtrl;
  late Animation<double> _tagFade;
  // Progress bar
  late AnimationController _progressCtrl;
  late Animation<double> _progress;
  // Fade in / out for whole screen
  late AnimationController _fadeInCtrl;
  late Animation<double> _fadeIn;
  late AnimationController _fadeOutCtrl;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    // Hex grid drifts slowly
    _hexCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Cipher ring rotates continuously
    _cipherCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    // Shield pulses in
    _shieldCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _shieldScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shieldCtrl, curve: Curves.elasticOut));
    _shieldGlow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _shieldCtrl, curve: Curves.easeOut));

    // Title slides in from left
    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleFade = CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut);
    _titleSlide = Tween<Offset>(begin: const Offset(-0.4, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));

    // Tagline fades in
    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeIn);

    // Progress bar fills over ~2.5 s
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    // Fade in
    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeInCtrl, curve: Curves.easeIn);

    // Fade out
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn));

    // Staggered sequence
    _fadeInCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _shieldCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        _titleCtrl.forward();
        _progressCtrl.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _tagCtrl.forward();
    });

    // Navigate after 3.6 s
    Timer(const Duration(milliseconds: 3600), () async {
      if (!mounted) return;
      await _fadeOutCtrl.forward();
      if (!mounted) return;
      await shrinkToLoginWindow();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _cipherCtrl.dispose();
    _shieldCtrl.dispose();
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    _progressCtrl.dispose();
    _fadeInCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeInCtrl, _fadeOutCtrl]),
        builder: (context, child) =>
            Opacity(opacity: _fadeIn.value * _fadeOut.value, child: child),
        child: Container(
          // Single diagonal gradient: top-left deep navy to bottom-right dark teal
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF040D1A), // very deep navy (top-left)
                Color(0xFF0A1628), // dark navy-blue
                Color(0xFF0D2137), // mid deep blue
                Color(0xFF071A2F), // bottom-right slightly teal-blue
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Layer 1: Animated hex grid (background texture)
              AnimatedBuilder(
                animation: _hexCtrl,
                builder: (context, _) => CustomPaint(
                  size: const Size(680, 320),
                  painter: _HexGridPainter(drift: _hexCtrl.value),
                ),
              ),

              // Layer 2: Main content row
              Positioned.fill(
                child: Row(
                  children: [
                    // LEFT PANEL — animated shield + cipher ring (40% width)
                    Expanded(
                      flex: 40,
                      child: Center(
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: AnimatedBuilder(
                            animation:
                                Listenable.merge([_cipherCtrl, _shieldCtrl]),
                            builder: (context, _) => CustomPaint(
                              painter: _VaultEmblemPainter(
                                cipherAngle: _cipherCtrl.value * 2 * math.pi,
                                shieldScale: _shieldScale.value,
                                shieldGlow: _shieldGlow.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Thin vertical divider
                    Container(
                      width: 1,
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF2E75B6).withOpacity(0.5),
                            const Color(0xFF58A6FF).withOpacity(0.7),
                            const Color(0xFF2E75B6).withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // RIGHT PANEL — title, tagline, progress (60% width)
                    Expanded(
                      flex: 60,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // VaultX title
                            FadeTransition(
                              opacity: _titleFade,
                              child: SlideTransition(
                                position: _titleSlide,
                                child: AnimatedBuilder(
                                  animation: _cipherCtrl,
                                  builder: (context, child) => ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        Color(0xFFCAE8FF),
                                        Color(0xFF58A6FF),
                                        Color(0xFF2E75B6),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: child,
                                  ),
                                  child: const Text(
                                    'VaultX',
                                    style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 4,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Tagline
                            FadeTransition(
                              opacity: _tagFade,
                              child: const Text(
                                'Secure  ·  Encrypted  ·  Vault',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6E8FAB),
                                  letterSpacing: 2.2,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Progress bar
                            FadeTransition(
                              opacity: _tagFade,
                              child: AnimatedBuilder(
                                animation: _progressCtrl,
                                builder: (context, _) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Bar track
                                    Container(
                                      width: double.infinity,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A2A3A),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _progress.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF1A4D7A),
                                                Color(0xFF2E75B6),
                                                Color(0xFF58A6FF),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF58A6FF)
                                                    .withOpacity(0.6),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Loading label
                                    Text(
                                      _getLoadingText(_progress.value),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF4A6A8A),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Version
                            FadeTransition(
                              opacity: _tagFade,
                              child: const Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF3A5068),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Corner accent: faint diagonal lines top-right
              Positioned(
                top: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(120, 120),
                  painter: _CornerAccentPainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLoadingText(double progress) {
    if (progress < 0.25) return 'INITIALIZING ENCRYPTION ENGINE...';
    if (progress < 0.55) return 'LOADING SECURE MODULES...';
    if (progress < 0.85) return 'VERIFYING VAULT INTEGRITY...';
    return 'READY';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEX GRID PAINTER — faint honeycomb texture that slowly drifts
// ─────────────────────────────────────────────────────────────────────────────
class _HexGridPainter extends CustomPainter {
  final double drift; // 0..1
  _HexGridPainter({required this.drift});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A3A5A).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const hexSize = 28.0;
    const w = hexSize * 2;
    const h = hexSize * 1.7320508; // sqrt(3)
    final offsetX = (drift * w * 0.5) % w;
    final offsetY = (drift * h * 0.3) % h;

    for (double y = -h + offsetY; y < size.height + h; y += h) {
      for (double x = -w + offsetX; x < size.width + w; x += w * 1.5) {
        _drawHex(canvas, paint, Offset(x, y), hexSize);
        _drawHex(canvas, paint, Offset(x + w * 0.75, y + h / 2), hexSize);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final px = center.dx + size * math.cos(angle);
      final py = center.dy + size * math.sin(angle);
      if (i == 0)
        path.moveTo(px, py);
      else
        path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexGridPainter old) => old.drift != drift;
}

// ─────────────────────────────────────────────────────────────────────────────
//  VAULT EMBLEM PAINTER
//  - Outer rotating cipher ring with tick marks (combination lock style)
//  - Middle counter-rotating gear ring
//  - Centre: animated shield that scales in, with a glowing keyhole
// ─────────────────────────────────────────────────────────────────────────────
class _VaultEmblemPainter extends CustomPainter {
  final double cipherAngle; // 0..2π rotating
  final double shieldScale; // 0..1 elastic pop-in
  final double shieldGlow; // 0..1 glow intensity

  _VaultEmblemPainter({
    required this.cipherAngle,
    required this.shieldScale,
    required this.shieldGlow,
  });

  static const Color _accent = Color(0xFF58A6FF);
  static const Color _mid = Color(0xFF2E75B6);
  static const Color _deep = Color(0xFF1A4D7A);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final c = Offset(cx, cy);

    // 1. Outer glow halo
    canvas.drawCircle(
      c,
      88,
      Paint()
        ..color = _mid.withOpacity(0.12 * shieldGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // 2. Outer cipher ring (rotating)
    _drawCipherRing(canvas, c, 82, cipherAngle);

    // 3. Middle decorative ring (counter-rotating, slower)
    _drawGearRing(canvas, c, 62, -cipherAngle * 0.4);

    // 4. Shield (scales in from centre)
    if (shieldScale > 0) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(shieldScale, shieldScale);
      canvas.translate(-cx, -cy);
      _drawShield(canvas, c, shieldGlow);
      canvas.restore();
    }
  }

  void _drawCipherRing(Canvas canvas, Offset c, double r, double angle) {
    // Ring track
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _deep.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Gradient arc overlay
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [
            _mid.withOpacity(0.9),
            _accent.withOpacity(0.3),
            _mid.withOpacity(0.9),
          ],
          transform: GradientRotation(angle),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Tick marks around the ring (like a combination lock dial)
    const ticks = 36;
    for (int i = 0; i < ticks; i++) {
      final a = angle + (2 * math.pi / ticks) * i;
      final isMajor = i % 9 == 0;
      final tickLen = isMajor ? 9.0 : 5.0;
      final inner = r - 4 - tickLen;
      final outer = r - 4;
      final p1 = Offset(c.dx + inner * math.cos(a), c.dy + inner * math.sin(a));
      final p2 = Offset(c.dx + outer * math.cos(a), c.dy + outer * math.sin(a));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = isMajor ? _accent.withOpacity(0.9) : _mid.withOpacity(0.5)
          ..strokeWidth = isMajor ? 1.5 : 0.8,
      );
    }
  }

  void _drawGearRing(Canvas canvas, Offset c, double r, double angle) {
    const teeth = 24;
    final path = Path();
    for (int i = 0; i < teeth * 2; i++) {
      final a = angle + (math.pi / teeth) * i;
      final rad = i.isEven ? r + 5.0 : r - 1.0;
      final px = c.dx + rad * math.cos(a);
      final py = c.dy + rad * math.sin(a);
      if (i == 0)
        path.moveTo(px, py);
      else
        path.lineTo(px, py);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _deep.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Inner circle of gear ring
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..color = _deep.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawShield(Canvas canvas, Offset c, double glow) {
    const sw = 46.0; // shield width
    const sh = 52.0; // shield height

    // Shield glow behind
    canvas.drawOval(
      Rect.fromCenter(center: c, width: sw * 1.6, height: sh * 1.5),
      Paint()
        ..color = _accent.withOpacity(0.15 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Shield shape path
    final path = Path();
    path.moveTo(c.dx, c.dy - sh / 2);
    path.cubicTo(
      c.dx + sw / 2,
      c.dy - sh / 2,
      c.dx + sw / 2,
      c.dy,
      c.dx,
      c.dy + sh / 2,
    );
    path.cubicTo(
      c.dx - sw / 2,
      c.dy,
      c.dx - sw / 2,
      c.dy - sh / 2,
      c.dx,
      c.dy - sh / 2,
    );
    path.close();

    // Shield fill gradient
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _mid.withOpacity(0.95),
            _deep.withOpacity(0.85),
          ],
        ).createShader(Rect.fromCenter(center: c, width: sw, height: sh))
        ..style = PaintingStyle.fill,
    );

    // Shield border
    canvas.drawPath(
      path,
      Paint()
        ..color = _accent.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Keyhole — circle part
    canvas.drawCircle(
      Offset(c.dx, c.dy - 5),
      8,
      Paint()
        ..color = const Color(0xFF0D1117)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(c.dx, c.dy - 5),
      8,
      Paint()
        ..color = _accent.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Keyhole stem
    final stemPath = Path()
      ..moveTo(c.dx - 4.5, c.dy + 3)
      ..lineTo(c.dx + 4.5, c.dy + 3)
      ..lineTo(c.dx + 3, c.dy + 14)
      ..lineTo(c.dx - 3, c.dy + 14)
      ..close();

    canvas.drawPath(
      stemPath,
      Paint()
        ..color = const Color(0xFF0D1117)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      stemPath,
      Paint()
        ..color = _accent.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Keyhole glow
    canvas.drawCircle(
      Offset(c.dx, c.dy - 5),
      10,
      Paint()
        ..color = _accent.withOpacity(0.20 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _VaultEmblemPainter old) =>
      old.cipherAngle != cipherAngle ||
      old.shieldScale != shieldScale ||
      old.shieldGlow != shieldGlow;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CORNER ACCENT — subtle geometric lines in the top-right corner
// ─────────────────────────────────────────────────────────────────────────────
class _CornerAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E75B6).withOpacity(0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final offset = i * 16.0;
      canvas.drawLine(
        Offset(size.width - offset, 0),
        Offset(size.width, offset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
