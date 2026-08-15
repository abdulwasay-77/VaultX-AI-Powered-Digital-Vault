// lib/screens/profile_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '_vault_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PROFILE SCREEN — matches PASSWORD/BACKUP screens' visual structure exactly
// ══════════════════════════════════════════════════════════════════════════════

// TODO: replace with your actual GitHub profile / portfolio URL.
const String kDeveloperName = 'Abdul Wasay';
const String kDeveloperLink = 'github.com/abdulwasay-77';
const String kAppVersion = '1.0.0';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _particleController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoadingAccount = true;
  String? _username;
  String? _email;
  String? _createdAt;
  bool _hasPin = false;

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
        parent: _entranceController, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();

    _loadAccountInfo();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountInfo() async {
    try {
      final info = await apiService.getAccountInfo();
      if (mounted) {
        setState(() {
          _username = info['username'] as String?;
          _email = info['email'] as String?;
          _createdAt = info['created_at'] as String?;
          _hasPin = info['has_pin'] == true;
          _isLoadingAccount = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAccount = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    return raw.split(' ').first.split('T').first;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D18),
      body: Stack(
        children: [
          // Particle background — same painter pattern as PasswordScreen/BackupScreen
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: _ProfileParticlePainter(_particleController.value),
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileHeader(),
                          const SizedBox(height: 20),
                          const _ChangePasswordCard(),
                          const SizedBox(height: 20),
                          _PinCard(
                            hasPin: _hasPin,
                            onPinUpdated: () => setState(() => _hasPin = true),
                          ),
                          const SizedBox(height: 20),
                          _AboutCard(onTap: () => _showAboutDialog(context)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar — identical structure to PasswordScreen's _buildTopBar() ─────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1E4A7A).withOpacity(0.3)),
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
              border: Border.all(color: const Color(0xFF1E4A7A).withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF2E75B6).withOpacity(0.08),
                    blurRadius: 12),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF2E75B6), Color(0xFF58A6FF)],
                  ).createShader(b),
                  child: const Icon(Icons.person_rounded,
                      size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
                  ).createShader(b),
                  child: const Text(
                    'PROFILE',
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
          // Member-since badge (same shape/role as Password screen's count badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E75B6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 12, color: Color(0xFF58A6FF)),
                const SizedBox(width: 6),
                Text(
                  _isLoadingAccount
                      ? 'Loading...'
                      : 'Member since ${_formatDate(_createdAt)}',
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

  // ── Profile header (avatar + username + email) ───────────────────────────
  Widget _buildProfileHeader() {
    return _ProfileCardShell(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6).withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text('🔐', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _isLoadingAccount
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF58A6FF)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _username ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email ?? '—',
                        style: const TextStyle(
                            color: Color(0xFF6E8FAB), fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AboutDialog());
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Particle painter — identical pattern to _PasswordParticlePainter
// ─────────────────────────────────────────────────────────────────────────
class _ProfileParticlePainter extends CustomPainter {
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

  const _ProfileParticlePainter(this.progress);

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
  bool shouldRepaint(_ProfileParticlePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────
//  Shared card shell — same gradient/border/shadow as Backup/Password cards
// ─────────────────────────────────────────────────────────────────────────
class _ProfileCardShell extends StatelessWidget {
  final Widget child;
  const _ProfileCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E75B6).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E75B6).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

Widget _cardHeader(IconData icon, String title, String subtitle) {
  return Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2E75B6).withOpacity(0.25),
              const Color(0xFF58A6FF).withOpacity(0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E75B6).withOpacity(0.4)),
        ),
        child: Icon(icon, color: const Color(0xFF58A6FF), size: 22),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
            ).createShader(r),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF5A7A9A), fontSize: 11)),
        ],
      ),
    ],
  );
}

Widget _successBox(String message) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF22C55E).withOpacity(0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline,
            color: Color(0xFF22C55E), size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
//  Change Master Password Card
// ─────────────────────────────────────────────────────────────────────────
class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _success = null;
    });

    if (_currentController.text.isEmpty || _newController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await apiService.changeMasterPassword(
          _currentController.text, _newController.text);
      if (mounted) {
        setState(() {
          _success = 'Master password updated successfully.';
          _isSubmitting = false;
        });
        _currentController.clear();
        _newController.clear();
        _confirmController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.lock_reset_rounded, 'CHANGE MASTER PASSWORD',
              'Update the password used to sign in'),
          const SizedBox(height: 16),
          VaultTextField(
            controller: _currentController,
            label: 'Current Password',
            hint: 'Enter your current master password',
            prefixIcon: Icons.lock_outline_rounded,
            obscure: _obscureCurrent,
            onToggleObscure: () =>
                setState(() => _obscureCurrent = !_obscureCurrent),
          ),
          const SizedBox(height: 12),
          VaultTextField(
            controller: _newController,
            label: 'New Password',
            hint: 'At least 8 characters',
            prefixIcon: Icons.lock_rounded,
            obscure: _obscureNew,
            onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 12),
          VaultTextField(
            controller: _confirmController,
            label: 'Confirm New Password',
            hint: 'Re-enter your new password',
            prefixIcon: Icons.lock_rounded,
            obscure: _obscureConfirm,
            onToggleObscure: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            VaultErrorBox(message: _error!),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12),
            _successBox(_success!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: VaultGradientButton(
              onPressed: _isSubmitting ? null : _submit,
              colors: const [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
              hoverColors: const [Color(0xFF3E85C6), Color(0xFF2A5D8A)],
              pressColor: const Color(0xFF1A4D7A),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Password',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  PIN Card (set or change)
// ─────────────────────────────────────────────────────────────────────────
class _PinCard extends StatefulWidget {
  final bool hasPin;
  final VoidCallback onPinUpdated;
  const _PinCard({required this.hasPin, required this.onPinUpdated});

  @override
  State<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<_PinCard> {
  final _masterPasswordController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _success = null;
    });

    if (_masterPasswordController.text.isEmpty) {
      setState(() => _error = 'Enter your master password to confirm.');
      return;
    }
    if (_newPinController.text.length != 4 ||
        int.tryParse(_newPinController.text) == null) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    if (_newPinController.text != _confirmPinController.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await apiService.setOrChangePin(
          _masterPasswordController.text, _newPinController.text);
      if (mounted) {
        setState(() {
          _success = widget.hasPin
              ? 'PIN updated successfully.'
              : 'PIN set successfully.';
          _isSubmitting = false;
        });
        _masterPasswordController.clear();
        _newPinController.clear();
        _confirmPinController.clear();
        widget.onPinUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.pin_rounded,
            widget.hasPin ? 'CHANGE QUICK-ACCESS PIN' : 'SET A QUICK-ACCESS PIN',
            'Confirm with your master password',
          ),
          const SizedBox(height: 16),
          VaultTextField(
            controller: _masterPasswordController,
            label: 'Master Password',
            hint: 'Confirm your identity',
            prefixIcon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: VaultTextField(
                  controller: _newPinController,
                  label: widget.hasPin ? 'New PIN' : 'PIN',
                  hint: '4 digits',
                  prefixIcon: Icons.pin_rounded,
                  obscure: true,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VaultTextField(
                  controller: _confirmPinController,
                  label: 'Confirm PIN',
                  hint: '4 digits',
                  prefixIcon: Icons.pin_rounded,
                  obscure: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            VaultErrorBox(message: _error!),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12),
            _successBox(_success!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: VaultGradientButton(
              onPressed: _isSubmitting ? null : _submit,
              colors: const [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
              hoverColors: const [Color(0xFF3E85C6), Color(0xFF2A5D8A)],
              pressColor: const Color(0xFF1A4D7A),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.hasPin ? 'Update PIN' : 'Set PIN',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  About Card (tappable, opens dialog)
// ─────────────────────────────────────────────────────────────────────────
class _AboutCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AboutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _ProfileCardShell(
          child: Row(
            children: [
              Expanded(
                child: _cardHeader(Icons.info_outline_rounded, 'ABOUT VAULTX',
                    'Version, credits & links'),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF5A7A9A), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  About Dialog
// ─────────────────────────────────────────────────────────────────────────
class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E75B6).withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E75B6).withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.shield_rounded, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
              ).createShader(r),
              child: const Text(
                'VaultX',
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            Text('Version $kAppVersion',
                style: const TextStyle(color: Color(0xFF6E8FAB), fontSize: 12)),
            const SizedBox(height: 18),
            const VaultDivider(),
            const SizedBox(height: 18),
            const Text(
              'AI-powered encrypted digital vault for passwords,\ndocuments, and notes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Developed by ',
                    style: TextStyle(color: Color(0xFF6E8FAB), fontSize: 12)),
                Text(kDeveloperName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              kDeveloperLink,
              style: const TextStyle(
                  color: Color(0xFF58A6FF), fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text('(tap and hold to select, then copy)',
                style: TextStyle(color: Color(0xFF3A5A7A), fontSize: 10)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: VaultGradientButton(
                onPressed: () => Navigator.of(context).pop(),
                colors: const [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
                hoverColors: const [Color(0xFF3E85C6), Color(0xFF2A5D8A)],
                pressColor: const Color(0xFF1A4D7A),
                child: const Text('Close',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
