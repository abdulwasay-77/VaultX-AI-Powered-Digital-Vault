import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import '_vault_shared.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Password mode controllers ──
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ── PIN mode controllers ──
  final TextEditingController _pinEmailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // ── Tab mode: 0 = password, 1 = PIN ──
  int _loginMode = 0;

  // ── Animations ──
  late AnimationController _bgCtrl;
  late AnimationController _cardCtrl;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late AnimationController _iconCtrl;
  late Animation<double> _iconGlow;
  late AnimationController _modeCtrl;

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
    _modeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _cardCtrl.forward();
    });

    // Listen to PIN field and auto-submit when 4 digits entered
    _pinController.addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pinEmailController.dispose();
    _pinController.removeListener(_onPinChanged);
    _pinController.dispose();
    _pinFocusNode.dispose();
    _bgCtrl.dispose();
    _cardCtrl.dispose();
    _iconCtrl.dispose();
    _modeCtrl.dispose();
    super.dispose();
  }

  // ── Auto-submit when 4th PIN digit is typed ──
  void _onPinChanged() {
    if (_pinController.text.length == 4 && !_isLoading) {
      _handlePinLogin();
    }
  }

  void _switchMode(int mode) {
    if (mode == _loginMode) return;
    setState(() {
      _loginMode = mode;
      _errorMessage = null;
      _modeCtrl.forward(from: 0);
    });
    if (mode == 1) {
      // Copy email over to PIN mode email field if already typed
      if (_emailController.text.isNotEmpty &&
          _pinEmailController.text.isEmpty) {
        _pinEmailController.text = _emailController.text;
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _pinFocusNode.requestFocus();
      });
    }
  }

  // ─────────────────────────── PASSWORD LOGIN ──────────────────────────────

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Email is required');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Password is required');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await apiService.login(
          _emailController.text, _passwordController.text);
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
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─────────────────────────── PIN LOGIN ───────────────────────────────────

  Future<void> _handlePinLogin() async {
    final email = _pinEmailController.text.trim();
    final pin = _pinController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email is required');
      return;
    }
    if (pin.length != 4) {
      setState(() => _errorMessage = 'Enter your 4-digit PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiService.loginWithPin(email, pin);
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
          _errorMessage = e.toString().replaceFirst('Exception: Connection failed: Exception: ', '');
          _isLoading = false;
          // Clear PIN so user can try again
          _pinController.clear();
        });
      }
    }
  }

  // ─────────────────────────── BUILD ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const VaultBackground(),
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
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Lock icon ──
                      Center(
                        child: AnimatedBuilder(
                          animation: _iconCtrl,
                          builder: (_, __) => VaultIconBadge(
                            icon: _loginMode == 1
                                ? Icons.pin_rounded
                                : Icons.lock_open_rounded,
                            glowValue: _iconGlow.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),

                      // ── Title ──
                      VaultTitle(
                        title: 'Welcome Back',
                        subtitle: _loginMode == 0
                            ? 'Sign in to your encrypted vault'
                            : 'Enter your 4-digit quick-access PIN',
                      ),
                      const SizedBox(height: 14),

                      // ── Mode tab switcher ──
                      _ModeSwitcher(
                        selected: _loginMode,
                        onSelect: _switchMode,
                      ),
                      const SizedBox(height: 14),

                      // ── Content area — fades between modes ──
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(
                                  _loginMode == 1 ? 0.04 : -0.04, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _loginMode == 0
                            ? _PasswordFields(
                                key: const ValueKey('password'),
                                emailController: _emailController,
                                passwordController: _passwordController,
                                obscurePassword: _obscurePassword,
                                isLoading: _isLoading,
                                errorMessage: _errorMessage,
                                onToggleObscure: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                onSubmit: _handleLogin,
                              )
                            : _PinFields(
                                key: const ValueKey('pin'),
                                emailController: _pinEmailController,
                                pinController: _pinController,
                                pinFocusNode: _pinFocusNode,
                                isLoading: _isLoading,
                                errorMessage: _errorMessage,
                                onSubmit: _handlePinLogin,
                              ),
                      ),

                      const SizedBox(height: 7),

                      // ── Create vault link ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have a vault?",
                              style: TextStyle(
                                  color: Color(0xFF5A7A9A), fontSize: 11.5)),
                          VaultTextLink(
                            label: 'Create One',
                            onPressed: () async {
                              await shrinkToRegisterWindow();
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterScreen()),
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
                          colors: const [Colors.transparent, Colors.transparent],
                          hoverColors: [
                            const Color(0xFFEF4444).withValues(alpha: 0.12),
                            const Color(0xFF991B1B).withValues(alpha: 0.18),
                          ],
                          pressColor:
                              const Color(0xFFEF4444).withValues(alpha: 0.25),
                          height: 36,
                          outlined: true,
                          outlineColor:
                              const Color(0xFFEF4444).withValues(alpha: 0.45),
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
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Mode switcher tabs (Password | PIN)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeSwitcher extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _ModeSwitcher({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            selected: selected == 0,
            onTap: () => onSelect(0),
            isFirst: true,
          ),
          _Tab(
            label: 'PIN',
            icon: Icons.pin_rounded,
            selected: selected == 1,
            onTap: () => onSelect(1),
            isFirst: false,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;

  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1A5FA8), Color(0xFF2E75B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E75B6).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF5A7A9A)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? Colors.white
                        : const Color(0xFF5A7A9A),
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Password mode fields
// ══════════════════════════════════════════════════════════════════════════════

class _PasswordFields extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _PasswordFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.errorMessage,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VaultTextField(
          controller: emailController,
          label: 'Email',
          hint: 'your@email.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 9),
        VaultTextField(
          controller: passwordController,
          label: 'Master Password',
          hint: '••••••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscure: obscurePassword,
          onToggleObscure: onToggleObscure,
          onSubmitted: (_) => onSubmit(),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          VaultErrorBox(message: errorMessage!),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: VaultGradientButton(
            onPressed: isLoading ? null : onSubmit,
            colors: const [Color(0xFF1A5FA8), Color(0xFF2E75B6)],
            hoverColors: const [Color(0xFF2277CC), Color(0xFF58A6FF)],
            pressColor: const Color(0xFF1A4D7A),
            height: 42,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded,
                          size: 15, color: Colors.white),
                      SizedBox(width: 7),
                      Text('Sign In',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: 0.4)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PIN mode fields
// ══════════════════════════════════════════════════════════════════════════════

class _PinFields extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController pinController;
  final FocusNode pinFocusNode;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  const _PinFields({
    super.key,
    required this.emailController,
    required this.pinController,
    required this.pinFocusNode,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Email field (required for PIN lookup)
        VaultTextField(
          controller: emailController,
          label: 'Email',
          hint: 'your@email.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // 4-dot PIN display + hidden input
        _PinDotDisplay(
          pinController: pinController,
          focusNode: pinFocusNode,
          isLoading: isLoading,
        ),

        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          VaultErrorBox(message: errorMessage!),
        ],
        const SizedBox(height: 14),

        // Manual submit button (for when auto-submit doesn't fire e.g. paste)
        SizedBox(
          width: double.infinity,
          child: VaultGradientButton(
            onPressed: isLoading ? null : onSubmit,
            colors: const [Color(0xFF1A5FA8), Color(0xFF2E75B6)],
            hoverColors: const [Color(0xFF2277CC), Color(0xFF58A6FF)],
            pressColor: const Color(0xFF1A4D7A),
            height: 42,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pin_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 7),
                      Text('Unlock with PIN',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: 0.4)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Animated 4-dot PIN display with hidden text field
// ══════════════════════════════════════════════════════════════════════════════

class _PinDotDisplay extends StatefulWidget {
  final TextEditingController pinController;
  final FocusNode focusNode;
  final bool isLoading;

  const _PinDotDisplay({
    required this.pinController,
    required this.focusNode,
    required this.isLoading,
  });

  @override
  State<_PinDotDisplay> createState() => _PinDotDisplayState();
}

class _PinDotDisplayState extends State<_PinDotDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));

    widget.pinController.addListener(_onPinChange);
  }

  void _onPinChange() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.pinController.removeListener(_onPinChange);
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int filled = widget.pinController.text.length.clamp(0, 4);

    return GestureDetector(
      onTap: () => widget.focusNode.requestFocus(),
      child: Column(
        children: [
          // Label
          const Text(
            'TAP BELOW AND TYPE YOUR PIN',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: Color(0xFF5A7A9A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Dot row
          AnimatedBuilder(
            animation: _shakeCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shake.value, 0),
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final bool isFilled = i < filled;
                final bool isCurrent = i == filled && filled < 4;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: isCurrent ? 20 : 16,
                  height: isCurrent ? 20 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? const Color(0xFF2E75B6)
                        : Colors.transparent,
                    border: Border.all(
                      color: isFilled
                          ? const Color(0xFF58A6FF)
                          : isCurrent
                              ? const Color(0xFF2E75B6)
                              : const Color(0xFF1E3A5F),
                      width: isCurrent ? 2.5 : 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2E75B6)
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),

          // Hidden text field that captures actual keystrokes
          SizedBox(
            height: 0,
            child: TextField(
              controller: widget.pinController,
              focusNode: widget.focusNode,
              maxLength: 4,
              keyboardType: TextInputType.number,
              obscureText: true,
              enabled: !widget.isLoading,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 0, color: Colors.transparent),
              cursorColor: Colors.transparent,
              cursorWidth: 0,
            ),
          ),
        ],
      ),
    );
  }
}