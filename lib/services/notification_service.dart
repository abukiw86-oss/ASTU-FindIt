import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<Map<String, dynamic>> getNotifications({required String userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-notifications&user_id=$userId'),
      );
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response'};
      }
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markAsRead({
    required int notificationId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=mark-notification-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notification_id': notificationId,
          'user_id': userId,
        }),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markAllAsRead({required String userId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=mark-all-notifications-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }
}