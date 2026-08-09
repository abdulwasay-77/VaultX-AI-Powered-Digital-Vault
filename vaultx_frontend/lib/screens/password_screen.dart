import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '_vault_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PASSWORD SCREEN — FULLY ENHANCED
// ══════════════════════════════════════════════════════════════════════════════

class PasswordScreen extends StatefulWidget {
  final List<PasswordEntry> passwords;
  final Future<void> Function() onRefresh;
  final int? highlightedPasswordId;

  const PasswordScreen({
    super.key,
    required this.passwords,
    required this.onRefresh,
    this.highlightedPasswordId,
  });

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _particleController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _getStrengthColor(int score) {
    if (score >= 90) return const Color(0xFF00C853);
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showViewDetailsDialog(PasswordEntry entry) async {
    try {
      final fullEntry = await apiService.getPasswordById(entry.id);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _ViewDetailsDialog(
          entry: fullEntry,
          onEdit: () {
            Navigator.pop(ctx);
            _showEditDialog(fullEntry);
          },
          // FIX: pop the view dialog BEFORE running the async delete flow
          onDelete: () {
            Navigator.pop(ctx);
            _deletePassword(fullEntry.id, fullEntry.title);
          },
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to load details: $e', isError: true);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditDialog(
        isEdit: false,
        initialTag: null,
        initialTitle: '',
        initialUsername: '',
        initialPassword: '',
        initialUrl: '',
        editingId: null,
        onRefresh: widget.onRefresh,
      ),
    );
  }

  void _showEditDialog(PasswordEntry entry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditDialog(
        isEdit: true,
        initialTitle: entry.title,
        initialUsername: entry.username ?? '',
        initialPassword: entry.password ?? '',
        initialUrl: entry.url ?? '',
        initialTag: entry.tag,
        editingId: entry.id,
        onRefresh: widget.onRefresh,
      ),
    );
  }

  Future<void> _deletePassword(int id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(title: title),
    );
    if (confirmed == true) {
      try {
        await apiService.deletePassword(id);
        await widget.onRefresh();
        _showSnackBar('Password deleted successfully');
      } catch (e) {
        _showSnackBar('Failed to delete password', isError: true);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D18),
      body: Stack(
        children: [
          // Particle background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: _PasswordParticlePainter(_particleController.value),
              ),
            ),
          ),
          // Content
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: widget.passwords.isEmpty
                        ? _buildEmptyState()
                        : _buildPasswordList(),
                  ),
                ],
              ),
            ),
          ),
          // Premium FAB
          Positioned(
            bottom: 28,
            right: 28,
            child: _PremiumFAB(onPressed: _showAddDialog),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF1E4A7A).withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E2340), Color(0xFF112B4E)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF1E4A7A).withOpacity(0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6).withOpacity(0.08),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF2E75B6), Color(0xFF58A6FF)],
                  ).createShader(b),
                  child:
                      const Icon(Icons.vpn_key, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
                  ).createShader(b),
                  child: const Text(
                    'PASSWORDS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E75B6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2E75B6).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 13, color: Color(0xFF58A6FF)),
                const SizedBox(width: 6),
                Text(
                  '${widget.passwords.length} stored',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF58A6FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E2340), Color(0xFF112B4E)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2E75B6).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6).withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.vpn_key_outlined,
                size: 42, color: Color(0xFF2E75B6)),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
            ).createShader(b),
            child: const Text(
              'No Passwords Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Click the + button to add your first password',
            style: TextStyle(
              color: Color(0xFF5A7A9A),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          _PremiumGradientButton(
            onPressed: _showAddDialog,
            label: 'Add First Password',
            icon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordList() {
    final passwords = [...widget.passwords]
      ..sort((a, b) {
        final aHighlighted = a.id == widget.highlightedPasswordId;
        final bHighlighted = b.id == widget.highlightedPasswordId;
        if (aHighlighted == bHighlighted) return 0;
        return aHighlighted ? -1 : 1;
      });
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: passwords.length,
      itemBuilder: (context, index) {
        final pwd = passwords[index];
        return _PasswordCard(
          password: pwd,
          onTap: () => _showViewDetailsDialog(pwd),
          getStrengthColor: _getStrengthColor,
          isHighlighted: pwd.id == widget.highlightedPasswordId,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PARTICLE BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════

class _PasswordParticlePainter extends CustomPainter {
  final double progress;
  static const int _count = 12;
  static final List<List<double>> _seeds = List.generate(
    _count,
    (i) => [
      (i * 137.5) % 1.0,
      (i * 91.3) % 1.0,
      0.3 + (i * 53.7) % 0.7,
      (i * 77.1) % 1.0,
    ],
  );

  const _PasswordParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < _count; i++) {
      final s = _seeds[i];
      final t = (progress + s[3]) % 1.0;
      final x = s[0] * size.width + math.sin(t * 2 * math.pi + i) * 30;
      final y = (s[1] + t * 0.3) % 1.0 * size.height;
      final radius = 1.5 + s[2] * 2.0;
      final opacity = 0.15 + math.sin(t * math.pi) * 0.15;
      paint.color = const Color(0xFF2E75B6).withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PasswordParticlePainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
//  PASSWORD CARD
// ══════════════════════════════════════════════════════════════════════════════

class _PasswordCard extends StatefulWidget {
  final PasswordEntry password;
  final VoidCallback onTap;
  final Color Function(int) getStrengthColor;
  final bool isHighlighted;

  const _PasswordCard({
    required this.password,
    required this.onTap,
    required this.getStrengthColor,
    this.isHighlighted = false,
  });

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strengthColor =
        widget.getStrengthColor(widget.password.strengthScore);
    final strengthLabel = widget.password.strengthScore >= 90
        ? 'Very Strong'
        : widget.password.strengthScore >= 70
            ? 'Strong'
            : widget.password.strengthScore >= 40
                ? 'Moderate'
                : 'Weak';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovering = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Transform.scale(
            scale: _scale.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_hovering || widget.isHighlighted)
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFF1E4A7A).withOpacity(0.4),
                  width: widget.isHighlighted ? 2 : 1.2,
                ),
                boxShadow: (_hovering || widget.isHighlighted)
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E75B6)
                              .withOpacity(widget.isHighlighted
                                  ? 0.45
                                  : 0.25 * _glow.value),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon badge
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF2E75B6).withOpacity(0.25),
                            const Color(0xFF2E75B6).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: const Color(0xFF2E75B6).withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(Icons.vpn_key,
                          color: Color(0xFF58A6FF), size: 24),
                    ),
                    const SizedBox(width: 16),
                    // Title + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.password.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (widget.password.tag != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E75B6)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF2E75B6)
                                          .withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(
                                    widget.password.tag!,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF58A6FF),
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  widget.password.username ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF6E8FAB)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Strength badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: strengthColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: strengthColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: strengthColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: strengthColor.withOpacity(0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                strengthLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: strengthColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 62,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: widget.password.strengthScore / 100,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                color: strengthColor,
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Chevron
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _hovering
                            ? const Color(0xFF2E75B6).withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: _hovering
                            ? const Color(0xFF58A6FF)
                            : const Color(0xFF5A7A9A),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIEW DETAILS DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _ViewDetailsDialog extends StatefulWidget {
  final PasswordEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ViewDetailsDialog({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ViewDetailsDialog> createState() => _ViewDetailsDialogState();
}

class _ViewDetailsDialogState extends State<_ViewDetailsDialog> {
  bool _obscurePassword = true;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStrengthColor(int score) {
    if (score >= 90) return const Color(0xFF00C853);
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final strengthColor = _getStrengthColor(entry.strengthScore);
    final strengthLabel = entry.strengthScore >= 90
        ? 'Very Strong'
        : entry.strengthScore >= 70
            ? 'Strong'
            : entry.strengthScore >= 40
                ? 'Moderate'
                : 'Weak';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 490,
        constraints: const BoxConstraints(maxHeight: 620),
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
            color: const Color(0xFF1E4A7A).withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 50,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: const Color(0xFF2E75B6).withOpacity(0.06),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF1E4A7A).withOpacity(0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E75B6).withOpacity(0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.vpn_key,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Password Details',
                          style: TextStyle(
                            color: Color(0xFF5A7A9A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _IconHoverButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Username',
                      value: entry.username ?? '—',
                      onCopy: entry.username != null
                          ? () => _copyToClipboard(entry.username!, 'Username')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Password
                    _DetailRow(
                      icon: Icons.lock_outline,
                      label: 'Password',
                      value: _obscurePassword
                          ? '••••••••••••'
                          : (entry.password ?? ''),
                      onCopy: entry.password != null
                          ? () => _copyToClipboard(entry.password!, 'Password')
                          : null,
                      trailingExtra: _IconHoverButton(
                        icon: _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? 'Show' : 'Hide',
                      ),
                    ),
                    if (entry.url != null && entry.url!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.link,
                        label: 'Website',
                        value: entry.url!,
                        isUrl: true,
                        onCopy: () => _copyToClipboard(entry.url!, 'URL'),
                      ),
                    ],
                    if (entry.tag != null) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.label_outline,
                        label: 'Category',
                        value: entry.tag!,
                        isTag: true,
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Strength
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: strengthColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: strengthColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: strengthColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.shield_outlined,
                                size: 18, color: strengthColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Strength',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF8B949E),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$strengthLabel  ${entry.strengthScore}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: strengthColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: entry.strengthScore / 100,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.08),
                                    color: strengthColor,
                                    minHeight: 5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Actions ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF1E4A7A).withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Close (left side)
                  _DialogButton(
                    label: 'Close',
                    color: const Color(0xFF5A7A9A),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Edit
                  _DialogButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF2E75B6),
                    filled: false,
                    onPressed: widget.onEdit,
                  ),
                  const SizedBox(width: 10),
                  // Delete — already pops dialog before running delete flow
                  _DialogButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: const Color(0xFFEF4444),
                    filled: false,
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widget for detail rows ────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final Widget? trailingExtra;
  final bool isUrl;
  final bool isTag;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
    this.trailingExtra,
    this.isUrl = false,
    this.isTag = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF2E75B6).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF2E75B6).withOpacity(0.2),
            ),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF4A90C4)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6E8FAB),
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              isTag
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E75B6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2E75B6).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFF58A6FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        color: isUrl ? const Color(0xFF58A6FF) : Colors.white,
                        fontSize: 14,
                        decoration: isUrl ? TextDecoration.underline : null,
                        decorationColor: const Color(0xFF58A6FF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
        if (trailingExtra != null) ...[
          const SizedBox(width: 4),
          trailingExtra!,
        ],
        if (onCopy != null) ...[
          const SizedBox(width: 4),
          _IconHoverButton(
            icon: Icons.copy_outlined,
            onPressed: onCopy!,
            tooltip: 'Copy',
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DELETE CONFIRM DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _DeleteConfirmDialog extends StatelessWidget {
  final String title;

  const _DeleteConfirmDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
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
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.06),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Delete Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  _IconHoverButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key,
                            size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This action cannot be undone. The password will be permanently removed from your vault.',
                    style: TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Row(
                children: [
                  _DialogButton(
                    label: 'Cancel',
                    color: const Color(0xFF5A7A9A),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const Spacer(),
                  _DialogButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: const Color(0xFFEF4444),
                    filled: true,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADD / EDIT DIALOG  — self-contained (no shared controllers from parent)
// ══════════════════════════════════════════════════════════════════════════════

class _AddEditDialog extends StatefulWidget {
  final bool isEdit;
  final String initialTitle;
  final String initialUsername;
  final String initialPassword;
  final String initialUrl;
  final String? initialTag;
  final int? editingId;
  final Future<void> Function() onRefresh;

  const _AddEditDialog({
    required this.isEdit,
    required this.initialTitle,
    required this.initialUsername,
    required this.initialPassword,
    required this.initialUrl,
    required this.initialTag,
    required this.editingId,
    required this.onRefresh,
  });

  @override
  State<_AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<_AddEditDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _urlCtrl;

  bool _obscurePassword = true;
  bool _isGenerating = false;
  bool _isSaving = false;
  PasswordStrengthResponse? _strength;
  String? _selectedTag;

  static const List<String> _tags = [
    'Bank',
    'Social',
    'Work',
    'Email',
    'Shopping',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _usernameCtrl = TextEditingController(text: widget.initialUsername);
    _passwordCtrl = TextEditingController(text: widget.initialPassword);
    _urlCtrl = TextEditingController(text: widget.initialUrl);
    _selectedTag = widget.initialTag;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStrengthColor(int score) {
    if (score >= 90) return const Color(0xFF00C853);
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _generatePassword() async {
    setState(() => _isGenerating = true);
    try {
      final result = await apiService.generatePassword();
      setState(() {
        _passwordCtrl.text = result.suggestions.first;
        _strength = result.strength;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty ||
        _usernameCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _showSnackBar('Please fill all required fields', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (widget.isEdit && widget.editingId != null) {
        await apiService.updatePassword(widget.editingId!, {
          'title': _titleCtrl.text,
          'username': _usernameCtrl.text,
          'password': _passwordCtrl.text,
          'url': _urlCtrl.text.isNotEmpty ? _urlCtrl.text : null,
          'tag': _selectedTag,
        });
      } else {
        await apiService.createPassword(PasswordCreateRequest(
          title: _titleCtrl.text,
          username: _usernameCtrl.text,
          password: _passwordCtrl.text,
          url: _urlCtrl.text.isNotEmpty ? _urlCtrl.text : null,
          tag: _selectedTag,
        ));
      }
      await widget.onRefresh();
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar(widget.isEdit ? 'Password updated!' : 'Password added!');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 660),
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
            color: const Color(0xFF1E4A7A).withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 50,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: const Color(0xFF2E75B6).withOpacity(0.06),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF1E4A7A).withOpacity(0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E75B6).withOpacity(0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isEdit ? Icons.edit_outlined : Icons.add,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEdit ? 'Edit Password' : 'Add Password',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isEdit
                            ? 'Update your credentials'
                            : 'Store new credentials securely',
                        style: const TextStyle(
                          color: Color(0xFF5A7A9A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _IconHoverButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── Form ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      controller: _titleCtrl,
                      label: 'Title *',
                      hint: 'e.g., Google Account',
                      icon: Icons.title_outlined,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _usernameCtrl,
                      label: 'Username / Email *',
                      hint: 'your@email.com',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    // Password row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _passwordCtrl,
                            label: 'Password *',
                            hint: 'Enter or generate',
                            icon: Icons.lock_outline,
                            obscure: _obscurePassword,
                            onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            onChanged: (v) async {
                              if (v.length >= 3) {
                                try {
                                  final s =
                                      await apiService.checkPasswordStrength(v);
                                  if (mounted) setState(() => _strength = s);
                                } catch (_) {
                                  if (mounted) setState(() => _strength = null);
                                }
                              } else {
                                if (mounted) setState(() => _strength = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Generate button
                        _PremiumIconButton(
                          onPressed: _isGenerating ? null : _generatePassword,
                          icon: Icons.auto_awesome,
                          color: const Color(0xFF2E75B6),
                          isLoading: _isGenerating,
                          tooltip: 'Generate',
                        ),
                      ],
                    ),
                    // Strength meter
                    if (_strength != null) ...[
                      const SizedBox(height: 14),
                      _buildStrengthMeter(_strength!),
                    ],
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _urlCtrl,
                      label: 'URL (optional)',
                      hint: 'https://example.com',
                      icon: Icons.link_outlined,
                    ),
                    const SizedBox(height: 14),
                    _buildTagDropdown(),
                  ],
                ),
              ),
            ),
            // ── Actions ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF1E4A7A).withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _DialogButton(
                    label: 'Cancel',
                    color: const Color(0xFF5A7A9A),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _PremiumGradientButton(
                    onPressed: _isSaving ? null : _save,
                    label: widget.isEdit ? 'Update' : 'Save Password',
                    icon: widget.isEdit ? Icons.save_outlined : Icons.add,
                    isLoading: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020810).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E3A5A).withOpacity(0.8),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: const Color(0xFF2E75B6),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF6E8FAB), fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF2A3A4A), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF4A7A9B), size: 18),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF4A7A9B),
                    size: 18,
                  ),
                  onPressed: onToggleObscure,
                  splashRadius: 16,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTagDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020810).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E3A5A).withOpacity(0.8),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedTag,
        dropdownColor: const Color(0xFF0E2340),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
          labelText: 'Category Tag',
          labelStyle: TextStyle(color: Color(0xFF6E8FAB), fontSize: 13),
          prefixIcon:
              Icon(Icons.label_outline, color: Color(0xFF4A7A9B), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        items: _tags
            .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t, style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectedTag = v),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A7A9B)),
      ),
    );
  }

  Widget _buildStrengthMeter(PasswordStrengthResponse strength) {
    final color = _getStrengthColor(strength.score);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                strength.category,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${strength.score}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: strength.score / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              color: color,
              minHeight: 5,
            ),
          ),
          if (strength.feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...strength.feedback.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 12, color: Color(0xFF6E8FAB)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8B949E)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED BUTTON COMPONENTS
// ══════════════════════════════════════════════════════════════════════════════

// ── Icon hover button (close, copy, visibility) ───────────────────────────────

class _IconHoverButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  const _IconHoverButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 18,
  });

  @override
  State<_IconHoverButton> createState() => _IconHoverButtonState();
}

class _IconHoverButtonState extends State<_IconHoverButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget btn = MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.onPressed != null) {
          setState(() => _hovering = true);
          _ctrl.forward();
        }
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _hovering
                    ? Colors.white.withOpacity(0.07)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: widget.size,
                color: _hovering
                    ? Colors.white.withOpacity(0.85)
                    : const Color(0xFF6E8FAB),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: btn,
      );
    }
    return btn;
  }
}

// ── Dialog button (Cancel / action) ──────────────────────────────────────────

class _DialogButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool filled;

  const _DialogButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.onPressed != null) {
          setState(() => _hovering = true);
          _ctrl.forward();
        }
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: widget.filled
                    ? LinearGradient(
                        colors: [
                          widget.color,
                          widget.color.withOpacity(0.8),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          widget.color.withOpacity(_hovering ? 0.15 : 0.0),
                          widget.color.withOpacity(_hovering ? 0.08 : 0.0),
                        ],
                      ),
                borderRadius: BorderRadius.circular(10),
                border: widget.filled
                    ? null
                    : Border.all(
                        color:
                            widget.color.withOpacity(0.35 + 0.3 * _glow.value),
                      ),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3 * _glow.value),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 15,
                      color: widget.filled ? Colors.white : widget.color,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.filled ? Colors.white : widget.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Premium gradient button (primary Save / Add) ──────────────────────────────

class _PremiumGradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool isLoading;

  const _PremiumGradientButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    this.isLoading = false,
  });

  @override
  State<_PremiumGradientButton> createState() => _PremiumGradientButtonState();
}

class _PremiumGradientButtonState extends State<_PremiumGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.onPressed != null) {
          setState(() => _hovering = true);
          _ctrl.forward();
        }
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _hovering
                      ? [const Color(0xFF2277CC), const Color(0xFF58A6FF)]
                      : [const Color(0xFF1A5FA8), const Color(0xFF2E75B6)],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E75B6)
                              .withOpacity(0.45 * _glow.value),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Premium icon button (generate) ───────────────────────────────────────────

class _PremiumIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final String? tooltip;

  const _PremiumIconButton({
    required this.onPressed,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.tooltip,
  });

  @override
  State<_PremiumIconButton> createState() => _PremiumIconButtonState();
}

class _PremiumIconButtonState extends State<_PremiumIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget btn = MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.onPressed != null) {
          setState(() => _hovering = true);
          _ctrl.forward();
        }
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(_hovering ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: widget.color.withOpacity(_hovering ? 0.55 : 0.3),
                ),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.25),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.color,
                        ),
                      )
                    : Icon(widget.icon, color: widget.color, size: 20),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

// ── Premium FAB ────────────────────────────────────────────────────────────────

class _PremiumFAB extends StatefulWidget {
  final VoidCallback onPressed;

  const _PremiumFAB({required this.onPressed});

  @override
  State<_PremiumFAB> createState() => _PremiumFABState();
}

class _PremiumFABState extends State<_PremiumFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovering = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _hovering
                      ? [const Color(0xFF2277CC), const Color(0xFF58A6FF)]
                      : [const Color(0xFF1A5FA8), const Color(0xFF2E75B6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E75B6)
                        .withOpacity(0.4 + 0.2 * _glow.value),
                    blurRadius: 16 + 8 * _glow.value,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
