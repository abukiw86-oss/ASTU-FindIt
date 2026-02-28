import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class NotificationService {
  final baseUrl = ApiService.baseUrl;

Future<Map<String, dynamic>> getNotifications(userId) async {
    try {
      final uri = Uri.parse('$baseUrl?action=get-notifications&user_id=$userId');
      final response = await http.get(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {
        'success': false,
        'message': 'Server responded with ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}