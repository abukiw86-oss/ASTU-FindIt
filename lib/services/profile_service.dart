import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ProfileService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<Map<String, dynamic>> getUserHistory({required int userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-history&user_id=$userId'),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'full_name': fullName,
          'phone': phone,
        }),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }
}