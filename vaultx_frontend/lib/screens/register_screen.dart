import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '_vault_shared.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  PasswordStrengthResponse? _strength;
  bool _isGenerating = false;
  String? _generatedPassword;

  late AnimationController _bgCtrl;
  late AnimationController _cardCtrl;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late AnimationController _iconCtrl;
  late Animation<double> _iconGlow;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _iconGlow = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _cardCtrl.forward();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _bgCtrl.dispose();
    _cardCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) async {
    if (value.length >= 3) {
      try {
        final strength = await apiService.checkPasswordStrength(value);
        if (mounted) setState(() => _strength = strength);
      } catch (_) {
        if (mounted) setState(() => _strength = null);
      }
    } else {
      if (mounted) setState(() => _strength = null);
    }
  }

  Future<void> _generatePassword() async {
    setState(() => _isGenerating = true);
    try {
      final result = await apiService.generatePassword();
      setState(() {
        _generatedPassword = result.suggestions.first;
        _passwordController.text = result.suggestions.first;
        _strength = result.strength;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to generate password'),
          backgroundColor: Color(0xFFEF4444),
        ));
      }
    }
  }

  void _copyGeneratedPassword() {
    if (_passwordController.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _passwordController.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password copied to clipboard'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_usernameController.text.isEmpty) {
      setState(() => _errorMessage = 'Username is required');
      return;
    }
    if (_usernameController.text.length < 3) {
      setState(() => _errorMessage = 'Username must be at least 3 characters');
      return;
    }
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Email is required');
      return;
    }
    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      setState(() => _errorMessage = 'Enter a valid email address');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Password is required');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await apiService.register(
        _passwordController.text,
        _usernameController.text.trim(),
        _emailController.text.trim(),
        pin: null,
      );
      await authService.setCurrentUser(response.userId, response.username);
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).setAuthenticated(
          true,
          username: response.username,
          userId: response.userId,
        );
        await expandToFullWindow();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  Color _strengthColor() {
    if (_strength == null) return const Color(0xFF8B949E);
    if (_strength!.score >= 70) return const Color(0xFF22C55E);
    if (_strength!.score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Whole-window gradient background (matches the card — no separate dark void)
          const VaultBackground(),
          // Floating vault-themed objects drifting across the window
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: VaultScenePainter(_bgCtrl.value),
              size: Size.infinite,
            ),
          ),
          FadeTransition(
            opacity: _cardFade,
            child: SlideTransition(
            position: _cardSlide,
            child: Center(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: SingleChildScrollView(
                  child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Icon ──
                      Center(
                        child: AnimatedBuilder(
                          animation: _iconCtrl,
                          builder: (_, __) => VaultIconBadge(
                            icon: Icons.person_add_alt_1_rounded,
                            glowValue: _iconGlow.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      VaultTitle(
                        title: 'Create Vault',
                        subtitle: 'Set up your encrypted vault',
                      ),
                      const SizedBox(height: 14),
                      // ── Username ──
                      VaultTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Choose a unique username',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 8),
                      // ── Email ──
                      VaultTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'your@email.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 8),
                      // ── Password row with generate / copy ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: VaultTextField(
                              controller: _passwordController,
                              label: 'Master Password',
                              hint: 'Minimum 8 characters',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              onToggleObscure: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              onChanged: _onPasswordChanged,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _IconActionButton(
                            icon: _isGenerating
                                ? null
                                : Icons.auto_awesome_rounded,
                            isLoading: _isGenerating,
                            tooltip: 'Generate strong password',
                            color: const Color(0xFF2E75B6),
                            onPressed: _isGenerating ? null : _generatePassword,
                          ),
                          if (_generatedPassword != null) ...[
                            const SizedBox(width: 5),
                            _IconActionButton(
                              icon: Icons.copy_rounded,
                              tooltip: 'Copy password',
                              color: const Color(0xFF22C55E),
                              onPressed: _copyGeneratedPassword,
                            ),
                          ],
                        ],
                      ),
                      // ── Strength meter ──
                      if (_strength != null) ...[
                        const SizedBox(height: 8),
                        _StrengthMeter(
                          strength: _strength!,
                          color: _strengthColor(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // ── Confirm password ──
                      VaultTextField(
                        controller: _confirmController,
                        label: 'Confirm Password',
                        hint: '••••••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscure: _obscureConfirm,
                        onToggleObscure: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      // ── Error ──
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        VaultErrorBox(message: _errorMessage!),
                      ],
                      const SizedBox(height: 14),
                      // ── Create Vault button ──
                      SizedBox(
                        width: double.infinity,
                        child: VaultGradientButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          colors: const [Color(0xFF1A5FA8), Color(0xFF2E75B6)],
                          hoverColors: const [
                            Color(0xFF2277CC),
                            Color(0xFF58A6FF)
                          ],
                          pressColor: const Color(0xFF1A4D7A),
                          height: 42,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_rounded,
                                        size: 15, color: Colors.white),
                                    SizedBox(width: 7),
                                    Text('Create Vault',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            letterSpacing: 0.4)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      // ── Sign in link ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have a vault?',
                              style: TextStyle(
                                  color: Color(0xFF5A7A9A), fontSize: 11.5)),
                          VaultTextLink(
                            label: 'Sign In',
                            onPressed: () async {
                              await shrinkToLoginWindow();
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const VaultDivider(),
                      const SizedBox(height: 8),
                      // ── Exit ──
                      SizedBox(
                        width: double.infinity,
                        child: VaultGradientButton(
                          onPressed: () => exit(0),
                          colors: [Colors.transparent, Colors.transparent],
                          hoverColors: [
                            const Color(0xFFEF4444).withOpacity(0.12),
                            const Color(0xFF991B1B).withOpacity(0.18),
                          ],
                          pressColor: const Color(0xFFEF4444).withOpacity(0.25),
                          height: 36,
                          outlined: true,
                          outlineColor:
                              const Color(0xFFEF4444).withOpacity(0.45),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.power_settings_new_rounded,
                                  size: 14, color: Color(0xFFEF4444)),
                              SizedBox(width: 6),
                              Text('Exit VaultX',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3)),
                            ],
                          ),
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
        ],
      ),
    );
  }
}

// ─── Small icon action button (generate / copy) ───
class _IconActionButton extends StatefulWidget {
  final IconData? icon;
  final bool isLoading;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _IconActionButton({
    this.icon,
    this.isLoading = false,
    required this.tooltip,
    required this.color,
    this.onPressed,
  });

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _hovering
                  ? widget.color.withOpacity(0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering ? widget.color : widget.color.withOpacity(0.5),
                width: 1.2,
              ),
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: widget.color))
                  : Icon(widget.icon, color: widget.color, size: 17),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Password strength meter ───
class _StrengthMeter extends StatelessWidget {
  final PasswordStrengthResponse strength;
  final Color color;
  const _StrengthMeter({required this.strength, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: strength.score / 100,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    color: color,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${strength.score}%',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strength.category,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w500, fontSize: 10.5),
          ),
          if (strength.feedback.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...strength.feedback.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 10, color: Color(0xFF5A7A9A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(f,
                            style: const TextStyle(
                                fontSize: 9.5, color: Color(0xFF5A7A9A))),
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
