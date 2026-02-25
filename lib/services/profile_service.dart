import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';

class ProfileService {
  static const String baseUrl = ApiService.baseUrl;

  // ==================== USER PROFILE METHODS ====================

  /// Get user profile by ID
  static Future<Map<String, dynamic>> getUserProfile({required int userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-profile&user_id=$userId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update user profile (name and phone only)
  static Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    try {

      final response = await http.post(
        Uri.parse('$baseUrl?action=update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_string_id': userId,
          'full_name': fullName,
          'phone': phone,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Change user password
  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {

      final response = await http.post(
        Uri.parse('$baseUrl?action=change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  static Future<Map<String, dynamic>> getUserHistory({required String userId}) async {
    try {
      
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-history&user_string_id=$userId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return {
          'success': true,
          'history': data['history'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load history',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get items reported by user
  static Future<Map<String, dynamic>> getUserReportedItems({required String userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-reported&user_string_id=$userId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get user's claims
  static Future<Map<String, dynamic>> getUserClaims({required int userId}) async {
    try {
      
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-claims&user_id=$userId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  static Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required String title,
    required String description,
    String? location,
    required String category,
    File? imageFile,
    required int userId,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl?action=update-item'),
      );

      // Add text fields
      request.fields['item_id'] = itemId.toString();
      request.fields['user_id'] = userId.toString();
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['location'] = location ?? '';
      request.fields['category'] = category;

      // Add image if provided
      if (imageFile != null) {
        if (await imageFile.exists()) {
          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          
          // Determine mime type
          String mimeType = 'image/jpeg';
          if (imageFile.path.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (imageFile.path.toLowerCase().endsWith('.gif')) {
            mimeType = 'image/gif';
          }

          var multipartFile = http.MultipartFile(
            'image',
            stream,
            length,
            filename: imageFile.path.split('/').last,
            contentType: MediaType.parse(mimeType),
          );
          request.files.add(multipartFile);
        }
      }

      // Send request
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete an item (only possible when status is 'pending')
  static Future<Map<String, dynamic>> deleteItem({
    required int itemId,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=delete-item'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_id': itemId,
          'user_id': userId,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get single item details
  static Future<Map<String, dynamic>> getItemDetails({required int itemId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-item&id=$itemId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== STATISTICS METHODS ====================

  static Future<Map<String, dynamic>> getUserStats({required String userId}) async {
    try {
      
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-stats&user_id=$userId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}