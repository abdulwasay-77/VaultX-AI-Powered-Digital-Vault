import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // ── Splash: wide short landscape window, no title bar ──
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(680, 320),
        minimumSize: Size(680, 320),
        maximumSize: Size(680, 320),
        center: true,
        backgroundColor: Color(0xFF020810),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'VaultX',
      ),
      () async {
        await windowManager.setResizable(false);
        await windowManager.show();
        await windowManager.focus();
      },
    );
    await ApiService.init();
    await authService.init();
    runApp(const VaultXApp());
  }, (error, stack) {
    print('====== CRASH ======');
    print('TYPE: ${error.runtimeType}');
    print('ERROR: $error');
    print('STACK:\n$stack');
    print('===================');
  });
}

// ── Login: compact portrait window, no title bar ──
Future<void> shrinkToLoginWindow() async {
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setResizable(false);
  await windowManager.setMinimumSize(const Size(600, 620));
  await windowManager.setMaximumSize(const Size(600, 620));
  await windowManager.setSize(const Size(600, 620));
  await windowManager.center();
}

// ── Register: same compact portrait size as login ──
Future<void> shrinkToRegisterWindow() async {
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setResizable(false);
  await windowManager.setMinimumSize(const Size(600, 620));
  await windowManager.setMaximumSize(const Size(600, 620));
  await windowManager.setSize(const Size(600, 620));
  await windowManager.center();
}

// ── Dashboard: full application window ──
Future<void> expandToFullWindow() async {
  await windowManager.setTitleBarStyle(TitleBarStyle.normal);
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(900, 620));
  await windowManager.setMaximumSize(const Size(9999, 9999));
  // Keep the restored dashboard window comfortably inside common laptop screens.
  await windowManager.setSize(const Size(1100, 700));
  await windowManager.center();
}

// ── Root application widget ──
class VaultXApp extends StatelessWidget {
  const VaultXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'VaultX',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF020810),
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(primary: Color(0xFF2E75B6)),
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// ── Auth state provider ──
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _username;
  int? _userId;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  int? get userId => _userId;

  void setAuthenticated(bool value, {String? username, int? userId}) {
    _isAuthenticated = value;
    _username = username;
    _userId = userId;
    notifyListeners();
  }

  void logout() async {
    await authService.logout();
    _isAuthenticated = false;
    _username = null;
    _userId = null;
    notifyListeners();
  }
}
