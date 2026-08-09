import 'dart:io';
import 'package:flutter/material.dart';
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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

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
    _emailController.dispose();
    _passwordController.dispose();
    _bgCtrl.dispose();
    _cardCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

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
                          icon: Icons.lock_open_rounded,
                          glowValue: _iconGlow.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    // ── Title ──
                    VaultTitle(
                      title: 'Welcome Back',
                      subtitle: 'Sign in to your encrypted vault',
                    ),
                    const SizedBox(height: 16),
                    // ── Fields ──
                    VaultTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'your@email.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 9),
                    VaultTextField(
                      controller: _passwordController,
                      label: 'Master Password',
                      hint: '••••••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    // ── Error ──
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      VaultErrorBox(message: _errorMessage!),
                    ],
                    const SizedBox(height: 14),
                    // ── Sign In ──
                    SizedBox(
                      width: double.infinity,
                      child: VaultGradientButton(
                        onPressed: _isLoading ? null : _handleLogin,
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
                        colors: [Colors.transparent, Colors.transparent],
                        hoverColors: [
                          const Color(0xFFEF4444).withOpacity(0.12),
                          const Color(0xFF991B1B).withOpacity(0.18),
                        ],
                        pressColor: const Color(0xFFEF4444).withOpacity(0.25),
                        height: 36,
                        outlined: true,
                        outlineColor: const Color(0xFFEF4444).withOpacity(0.45),
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