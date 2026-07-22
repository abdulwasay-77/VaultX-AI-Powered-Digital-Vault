import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/models.dart';

class RiskDashboardScreen extends StatefulWidget {
  const RiskDashboardScreen({super.key});

  @override
  State<RiskDashboardScreen> createState() => _RiskDashboardScreenState();
}

class _RiskDashboardScreenState extends State<RiskDashboardScreen>
    with TickerProviderStateMixin {
  // Existing controllers
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late AnimationController _scoreAnimationController;

  // NEW: Additional 3D effect controllers
  late AnimationController _orbitController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _entranceController;

  RiskReport? _riskReport;
  bool _isLoading = true;
  String? _errorMessage;

  late Animation<double> _scoreAnimation;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();

    // Original controllers (kept same durations for compatibility)
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scoreAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // NEW: Counter-rotating outer orbit ring
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();

    // NEW: Shimmer sweep effect
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // NEW: Floating particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    // NEW: Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();
    _loadRiskReport();
  }

  Future<void> _loadRiskReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final report = await apiService.getRiskReport();
      _scoreAnimation = Tween<double>(
        begin: 0,
        end: report.healthScore.toDouble(),
      ).animate(CurvedAnimation(
        parent: _scoreAnimationController,
        curve: Curves.easeOutCubic,
      ));
      setState(() {
        _riskReport = report;
        _isLoading = false;
      });
      _scoreAnimationController.forward(from: 0);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _scoreAnimationController.reset();
    await _loadRiskReport();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _scoreAnimationController.dispose();
    _orbitController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D18),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _riskReport == null
                  ? const Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(color: Color(0xFF8B949E)),
                      ),
                    )
                  : FadeTransition(
                      opacity: _entranceFade,
                      child: SlideTransition(
                        position: _entranceSlide,
                        child: _buildContent(),
                      ),
                    ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: AnimatedBuilder(
              animation: _spinController,
              builder: (_, __) => CustomPaint(
                painter: _LoadingRingPainter(_spinController.value),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Analyzing vault security...',
            style: TextStyle(
              color: Color(0xFF5A7A9A),
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.3),
              ),
            ),
            child: const Icon(Icons.error_outline,
                size: 48, color: Color(0xFFEF4444)),
          ),
          const SizedBox(height: 20),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFF8B949E)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildPremiumRetryButton(),
        ],
      ),
    );
  }

  Widget _buildPremiumRetryButton() {
    return _HoverButton(
      onTap: _refresh,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E75B6), Color(0xFF58A6FF)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E75B6).withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text(
          'Try Again',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          _buildTopBar(),
          const SizedBox(height: 24),
          _buildStunning3DHealthCard(),
          const SizedBox(height: 20),
          _buildStatisticsRow(),
          const SizedBox(height: 20),
          _buildWeakPasswordsSection(),
          const SizedBox(height: 20),
          _buildReusedPasswordsSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2E75B6).withOpacity(0.15),
                const Color(0xFF58A6FF).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF2E75B6).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF2E75B6), Color(0xFF58A6FF)],
                ).createShader(bounds),
                child:
                    const Icon(Icons.security, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF58A6FF), Color(0xFFADD4FF)],
                ).createShader(bounds),
                child: const Text(
                  'RISK DASHBOARD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _HoverButton(
          onTap: _refresh,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0E2340),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2E75B6).withOpacity(0.3),
              ),
            ),
            child:
                const Icon(Icons.refresh, color: Color(0xFF58A6FF), size: 18),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STUNNING 3D HOLOGRAPHIC HEALTH CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildStunning3DHealthCard() {
    final healthColor = _riskReport!.getHealthColor();
    final healthLabel = _riskReport!.getHealthLabel();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _spinController,
        _pulseController,
        _scoreAnimation,
        _orbitController,
        _shimmerController,
        _particleController,
      ]),
      builder: (context, child) {
        final spinAngle = _spinController.value * 2 * math.pi;
        final orbitAngle = -_orbitController.value * 2 * math.pi;
        final pulseValue = 0.7 + (_pulseController.value * 0.3);
        final shimmerAngle = _shimmerController.value * 2 * math.pi;
        final currentScore = _scoreAnimation.value;
        final progress = currentScore / 100.0;

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0E2340),
                Color(0xFF112B4E),
                Color(0xFF0C1E36),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  healthColor.withOpacity(0.2 + _pulseController.value * 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: healthColor.withOpacity(0.08 * pulseValue),
                blurRadius: 40 * pulseValue,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: const Color(0xFF2E75B6).withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: healthColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: healthColor.withOpacity(0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'VAULT HEALTH SCORE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.5,
                        color: const Color(0xFF8B949E).withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: healthColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: healthColor.withOpacity(0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ═══ THE 3D HOLOGRAPHIC RING ═══
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Layer 1: Ambient glow base
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: healthColor.withOpacity(0.04 * pulseValue),
                              blurRadius: 80,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),

                      // Layer 2: Outer rotating orbit with dashes (counter-spin)
                      Transform.rotate(
                        angle: orbitAngle,
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _OrbitDashRingPainter(
                            color: healthColor,
                            pulseValue: pulseValue,
                          ),
                        ),
                      ),

                      // Layer 3: Main 3D arc progress ring (spins slowly)
                      Transform.rotate(
                        angle: spinAngle * 0.15,
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _Hologram3DArcPainter(
                            progress: progress,
                            color: healthColor,
                            rotationAngle: spinAngle,
                            pulseValue: pulseValue,
                            shimmerAngle: shimmerAngle,
                          ),
                        ),
                      ),

                      // Layer 4: Inner rotating tech ring
                      Transform.rotate(
                        angle: spinAngle * 0.5,
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _TechInnerRingPainter(
                            color: healthColor,
                            pulseValue: pulseValue,
                          ),
                        ),
                      ),

                      // Layer 5: Floating orbital particles
                      CustomPaint(
                        size: const Size(260, 260),
                        painter: _OrbitalParticlesPainter(
                          color: healthColor,
                          animValue: _particleController.value,
                          spinAngle: spinAngle,
                        ),
                      ),

                      // Layer 6: 3D sphere inner glow
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.3),
                            colors: [
                              healthColor.withOpacity(0.22 * pulseValue),
                              healthColor.withOpacity(0.08),
                              const Color(0xFF040D18).withOpacity(0.6),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                          border: Border.all(
                            color: healthColor.withOpacity(0.25 * pulseValue),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: healthColor.withOpacity(0.15 * pulseValue),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      // Layer 7: Specular highlight on sphere
                      Positioned(
                        top: 68,
                        left: 88,
                        child: Container(
                          width: 28,
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.35 * pulseValue),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Layer 8: Center score text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Score number with 3D gradient text
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white,
                                healthColor,
                                healthColor.withOpacity(0.6),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: Text(
                              currentScore.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 58,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // "/ 100" label
                          Text(
                            '/ 100',
                            style: TextStyle(
                              fontSize: 11,
                              color: healthColor.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Health label badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: healthColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: healthColor.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              healthLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: healthColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Progress bar at bottom with percentage markers
                _buildProgressBar(progress, healthColor),

                const SizedBox(height: 20),

                // Footer stat
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: const Color(0xFF8B949E).withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Based on ${_riskReport!.totalPasswords} stored passwords',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B949E),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(double progress, Color healthColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Markers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['0', '25', '50', '75', '100']
              .map((v) => Text(
                    v,
                    style: TextStyle(
                      fontSize: 9,
                      color: const Color(0xFF5A7A9A).withOpacity(0.7),
                      letterSpacing: 0.3,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // Progress track
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        healthColor.withOpacity(0.6),
                        healthColor,
                        Colors.white.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: healthColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STATISTICS ROW
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatisticsRow() {
    return Row(
      children: [
        _buildStatCard(
          label: 'Strong',
          count: _riskReport!.strongPasswordsCount,
          color: const Color(0xFF22C55E),
          icon: Icons.check_circle_outline,
          sublabel: 'passwords',
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Moderate',
          count: _riskReport!.moderatePasswordsCount,
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_outlined,
          sublabel: 'passwords',
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Weak',
          count: _riskReport!.weakPasswordsCount,
          color: const Color(0xFFEF4444),
          icon: Icons.error_outline,
          sublabel: 'passwords',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required String sublabel,
  }) {
    return Expanded(
      child: _HoverScaleWidget(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0E2340),
                const Color(0xFF0C1E36),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, color.withOpacity(0.8)],
                ).createShader(bounds),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                sublabel,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF5A7A9A),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WEAK PASSWORDS SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildWeakPasswordsSection() {
    if (!_riskReport!.hasWeakPasswords) {
      return _buildAllClearCard(
        'No weak passwords found! Your vault is secure.',
        Icons.check_circle,
        const Color(0xFF22C55E),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'WEAK PASSWORDS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${_riskReport!.weakPasswords.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFEF4444).withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _riskReport!.weakPasswords.length,
            separatorBuilder: (_, __) => Container(
              height: 1,
              color: Colors.white.withOpacity(0.04),
            ),
            itemBuilder: (context, index) {
              final item = _riskReport!.weakPasswords[index];
              return _buildWeakPasswordTile(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeakPasswordTile(WeakPasswordItem item) {
    final strengthColor = item.getStrengthColor();
    final scorePercent = item.strengthScore / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Circular strength gauge
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(46, 46),
                  painter: _MiniGaugePainter(
                    progress: scorePercent,
                    color: strengthColor,
                  ),
                ),
                Text(
                  '${item.strengthScore}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: strengthColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (item.tag != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          item.tag!,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: strengthColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: strengthColor.withOpacity(0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.getStrengthLabel(),
                      style: TextStyle(
                        fontSize: 10,
                        color: strengthColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  REUSED PASSWORDS SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildReusedPasswordsSection() {
    if (!_riskReport!.hasReusedPasswords) {
      return _buildAllClearCard(
        'No reused passwords found! Each password is unique.',
        Icons.check_circle,
        const Color(0xFF22C55E),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sync_alt,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'REUSED PASSWORDS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${_riskReport!.reusedPasswords.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFF59E0B).withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _riskReport!.reusedPasswords.length,
            separatorBuilder: (_, __) => Container(
              height: 1,
              color: Colors.white.withOpacity(0.04),
            ),
            itemBuilder: (context, index) {
              final group = _riskReport!.reusedPasswords[index];
              return _buildReusedPasswordGroupTile(group);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReusedPasswordGroupTile(ReusedPasswordGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.25),
              ),
            ),
            child: Center(
              child: Text(
                '×${group.count}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Used in ${group.count} entries',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  group.entryTitles.take(3).join(', ') +
                      (group.count > 3
                          ? ' and ${group.count - 3} more...'
                          : ''),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllClearCard(String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2340), Color(0xFF0C1E36)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS — 3D HOLOGRAPHIC RING SYSTEM
// ═══════════════════════════════════════════════════════════════════

/// Main 3D arc painter — the core progress ring with depth shading
class _Hologram3DArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double rotationAngle;
  final double pulseValue;
  final double shimmerAngle;

  _Hologram3DArcPainter({
    required this.progress,
    required this.color,
    required this.rotationAngle,
    required this.pulseValue,
    required this.shimmerAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;

    // === TRACK (background ring) ===
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.06);
    canvas.drawCircle(center, radius, trackPaint);

    // === SHADOW ARC (depth effect below) ===
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = color.withOpacity(0.25 * pulseValue);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      shadowPaint,
    );

    // === MAIN GRADIENT ARC ===
    // Build sweep gradient manually with multiple arc segments
    final sweepSteps = 80;
    final sweepAngle = 2 * math.pi * progress;
    final stepAngle = sweepAngle / sweepSteps;

    for (int i = 0; i < sweepSteps; i++) {
      final t = i / sweepSteps;
      final startAngle = -math.pi / 2 + stepAngle * i;

      // Color transitions: dim at start → bright mid → white tip
      Color segmentColor;
      if (t < 0.1) {
        segmentColor = color.withOpacity(0.4 + t * 3);
      } else if (t < 0.85) {
        segmentColor = color.withOpacity(0.85 + (t - 0.1) * 0.18);
      } else {
        final tip = (t - 0.85) / 0.15;
        segmentColor = Color.lerp(color, Colors.white, tip * 0.8)!;
      }

      // 3D highlight: top of ring is lighter
      final angle = startAngle + stepAngle / 2;
      final highlightFactor = (math.sin(angle + math.pi / 2) * 0.5 + 0.5);
      segmentColor = Color.lerp(
        segmentColor,
        Colors.white,
        highlightFactor * 0.2,
      )!;

      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = i == 0 ? StrokeCap.round : StrokeCap.butt
        ..color = segmentColor;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        stepAngle + 0.005,
        false,
        segPaint,
      );
    }

    // === SHIMMER SWEEP ===
    if (progress > 0.05) {
      final shimmerPos = -math.pi / 2 + shimmerAngle % (sweepAngle);
      if (shimmerAngle % (2 * math.pi) < sweepAngle) {
        final shimmerPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = Colors.white.withOpacity(0.5 * pulseValue);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          shimmerPos - 0.15,
          0.3,
          false,
          shimmerPaint,
        );
      }
    }

    // === TIP GLOW SPARK ===
    if (progress > 0.02) {
      final tipAngle = -math.pi / 2 + 2 * math.pi * progress;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      final tipOffset = Offset(tipX, tipY);

      final tipGlow = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = Colors.white.withOpacity(0.8 * pulseValue);
      canvas.drawCircle(tipOffset, 8, tipGlow);

      final tipDot = Paint()
        ..color = Colors.white.withOpacity(0.95 * pulseValue);
      canvas.drawCircle(tipOffset, 4, tipDot);
    }
  }

  @override
  bool shouldRepaint(covariant _Hologram3DArcPainter old) => true;
}

/// Outer orbit dashed ring (counter-rotates)
class _OrbitDashRingPainter extends CustomPainter {
  final Color color;
  final double pulseValue;

  _OrbitDashRingPainter({required this.color, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    const dashCount = 48;
    const dashAngle = 0.04;
    const gapAngle = (2 * math.pi / dashCount) - dashAngle;

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.15 * pulseValue);

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (dashAngle + gapAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        dashPaint,
      );
    }

    // Outer ring faint glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..color = color.withOpacity(0.08 * pulseValue);
    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitDashRingPainter old) => true;
}

/// Inner tech ring with tick marks (spins)
class _TechInnerRingPainter extends CustomPainter {
  final Color color;
  final double pulseValue;

  _TechInnerRingPainter({required this.color, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 44;

    // Inner ring base
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withOpacity(0.1 * pulseValue);
    canvas.drawCircle(center, radius, ringPaint);

    // Tick marks at every 30°
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.3 * pulseValue);

    for (int i = 0; i < 12; i++) {
      final angle = i * (2 * math.pi / 12);
      final inner = radius - 6;
      final outer = radius + 2;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle),
            center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle),
            center.dy + outer * math.sin(angle)),
        tickPaint,
      );
    }

    // Minor ticks
    final minorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.15 * pulseValue);

    for (int i = 0; i < 60; i++) {
      if (i % 5 == 0) continue;
      final angle = i * (2 * math.pi / 60);
      final inner = radius - 3;
      final outer = radius + 1;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle),
            center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle),
            center.dy + outer * math.sin(angle)),
        minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TechInnerRingPainter old) => true;
}

/// Orbital particles that drift around the ring
class _OrbitalParticlesPainter extends CustomPainter {
  final Color color;
  final double animValue;
  final double spinAngle;

  _OrbitalParticlesPainter({
    required this.color,
    required this.animValue,
    required this.spinAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRadius = size.width / 2 - 18;

    // 6 particles at different orbit positions
    final particles = [
      (0.0, 1.0, 3.0),
      (0.17, 0.7, 2.5),
      (0.33, 0.9, 4.0),
      (0.5, 0.6, 2.0),
      (0.67, 0.8, 3.5),
      (0.83, 0.5, 2.8),
    ];

    for (final p in particles) {
      final offset = p.$1;
      final opacity = p.$2;
      final size2 = p.$3;

      final angle = spinAngle + offset * 2 * math.pi;
      final px = center.dx + orbitRadius * math.cos(angle);
      final py = center.dy + orbitRadius * math.sin(angle);

      final glowPaint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = color.withOpacity(0.35 * opacity * (0.5 + animValue * 0.5));
      canvas.drawCircle(Offset(px, py), size2 + 3, glowPaint);

      final dotPaint = Paint()..color = Colors.white.withOpacity(0.7 * opacity);
      canvas.drawCircle(Offset(px, py), size2 / 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalParticlesPainter old) => true;
}

/// Mini circular gauge for weak password tiles
class _MiniGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _MiniGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.85);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniGaugePainter old) => false;
}

/// Loading ring painter
class _LoadingRingPainter extends CustomPainter {
  final double value;
  _LoadingRingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF2E75B6).withOpacity(0.15);
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF58A6FF);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      value * 2 * math.pi - math.pi / 2,
      math.pi * 1.2,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingRingPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════
//  HOVER HELPERS
// ═══════════════════════════════════════════════════════════════════

class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverButton({required this.child, required this.onTap});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}

class _HoverScaleWidget extends StatefulWidget {
  final Widget child;
  const _HoverScaleWidget({required this.child});

  @override
  State<_HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<_HoverScaleWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: widget.child,
      ),
    );
  }
}
