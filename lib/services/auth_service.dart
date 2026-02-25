import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyUser = 'user_data';
  static const String _keyIsLoggedIn = 'is_logged_in';
 
// In auth_service.dart
static Future<void> saveUser({
  required String userStringId,
  required String email,
  required String fullName,
  required String? phone,
  required String role,
}) async {
  final prefs = await SharedPreferences.getInstance();


  final userMap = {
    'user_string_id': userStringId, 
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'role': role,
  };

  await prefs.setString(_keyUser, jsonEncode(userMap));
  await prefs.setBool(_keyIsLoggedIn, true);
}
// Add getter for string ID
static Future<String?> getUserStringId() async {
  final user = await getUser();
  return user?['user_string_id'] as String?;
}
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  /// Quick checks
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<bool> isAdmin() async {
    final user = await getUser();
    return user?['role'] == 'admin';
  }

  static Future<String?> getUserName() async {
    final user = await getUser();
    return user?['full_name'] as String?;
  }

  static Future<int?> getUserId() async {
    final user = await getUser();
    return user?['id'] as int?;
  }

  static Future<String?> getUserEmail() async {
    final user = await getUser();
    return user?['email'] as String?;
  }

  /// Clear everything on logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await prefs.remove(_keyIsLoggedIn);
  }
}