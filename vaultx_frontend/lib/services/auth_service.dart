import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  SharedPreferences? _prefs; // nullable, NOT late

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> setCurrentUser(int userId, String username) async {
    await _prefs?.setInt('current_user_id', userId);
    await _prefs?.setString('current_username', username);
  }

  Future<int?> getCurrentUserId() async {
    return _prefs?.getInt('current_user_id');
  }

  Future<String?> getCurrentUsername() async {
    return _prefs?.getString('current_username');
  }

  Future<void> clearCurrentUser() async {
    await _prefs?.remove('current_user_id');
    await _prefs?.remove('current_username');
    await apiService.clearToken();
  }

  Future<void> logout() async {
    await clearCurrentUser();
  }

  Future<bool> isLoggedIn() async {
    final token = await apiService.getToken();
    final userId = await getCurrentUserId();
    return token != null && token.isNotEmpty && userId != null;
  }
}

final authService = AuthService();
