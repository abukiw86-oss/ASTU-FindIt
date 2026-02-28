import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'package:path/path.dart' as path; // 

class ProfileService {
  static const String baseUrl = ApiService.baseUrl;

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

static Future<Map<String, dynamic>> getUserHistory({required String userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-history&user_string_id=$userId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from hitjkbf server'};
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

static Future<Map<String, dynamic>> deleteItem({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=delete-item'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_string_id': itemId,
          'user_string_id': userId,
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

static Future<Map<String, dynamic>> updateItem({
    required String itemId,
    required String userStringId,
    required String title,
    required String description,
    required String location,
    required String category,
    required List<String> keptImagePaths,
    required List<String> removedImagePaths,
    required List<File> newImages, 
  }) async {

    try {
      final uri = Uri.parse('$baseUrl?action=update-item');

      var request = http.MultipartRequest('POST', uri);

      request.fields['item_string_id'] = itemId.toString();
      request.fields['user_string_id'] = userStringId;
      request.fields['title'] = title.trim();
      request.fields['description'] = description.trim();
      request.fields['location'] = location.trim();
      request.fields['category'] = category;

      if (keptImagePaths.isNotEmpty) {
        request.fields['kept_images'] = jsonEncode(keptImagePaths);
      }

      if (removedImagePaths.isNotEmpty) {
        request.fields['removed_images'] = jsonEncode(removedImagePaths);
      }

      for (var file in newImages) {
        var multipartFile = await http.MultipartFile.fromPath(
          'new_images[]',
          file.path,
          filename: path.basename(file.path),
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();

      final statusCode = streamedResponse.statusCode;
      final responseBody = await streamedResponse.stream.bytesToString();

      if (statusCode != 200) {
        return {
          'success': false,
          'message': 'Server returned status $statusCode',
          'body': responseBody,
        };
      }

      try {
        final json = jsonDecode(responseBody);
        return json as Map<String, dynamic>;
      } catch (e) {
        return {
          'success': false,
          'message': 'Invalid JSON response from server',
          'body': responseBody,
          'parseError': e.toString(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network or upload error: $e',
      };
    }
  }

}