import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  static const String baseUrl = "https://astufindit.x10.mx/index/api.php"; 

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl?action=register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone ?? '',
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {'success': true, 'message': data['message'] ?? 'Registered'};
    } else {
      return {
        'success': false,
        'message': data['error'] ?? 'Registration failed',
        'status': response.statusCode,
      };
    }
  }

static Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl?action=login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  final data = jsonDecode(response.body);

  // Improved handling
  if (response.statusCode == 200 && data['message'] == 'Logged in successfully') {
    return {
      'success': true,
      'user': data['user'],
      'message': 'Login successful',
    };
  } else {
    return {
      'success': false,
      'message': data['error'] ?? data['message'] ?? 'Login failed - unknown reason',
      'status': response.statusCode,
    };
  }
}

static Future<Map<String, dynamic>> getItems({required String type}) async {
    // type = "lost" or "found"
    final response = await http.get(
      Uri.parse('$baseUrl?action=list-items&type=$type'),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['items'] != null) {
      return {
        'success': true,
        'items': data['items'] as List<dynamic>,
      };
    } else {
      return {
        'success': false,
        'message': data['error'] ?? 'Failed to load items',
      };
    }
  }
static Future<Map<String, dynamic>> reportItem({
  required String type,
  required String title,
  required String description,
  String? location,
  String? category,
  File? imageFile,
  required String reporterName,
  required String reporterPhone,
}) async {
  try {
    print('=' * 50);
    print('📤 API SERVICE - Preparing request');
    print('=' * 50);
    
    // FIX: Ensure type is not empty and is valid
    String finalType = type.trim().toLowerCase();
    if (finalType.isEmpty) {
      print('⚠️ CRITICAL: type is empty in ApiService! Setting to default "lost"');
      finalType = 'lost';
    }
    
    if (finalType != 'lost' && finalType != 'found') {
      print('⚠️ CRITICAL: invalid type "$finalType" in ApiService! Setting to default "lost"');
      finalType = 'lost';
    }
    
    print('📤 Final type being sent: "$finalType"');
    print('📤 Title: "$title"');
    print('📤 Reporter: "$reporterName"');
    print('📤 Phone: "$reporterPhone"');
    
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl?action=report-item'),
    );

    // FIX: Add fields one by one with explicit values
    request.fields['type'] = finalType;  // Use the validated type
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['location'] = location ?? '';
    request.fields['category'] = category ?? 'other';
    request.fields['reporter_name'] = reporterName;
    request.fields['reporter_phone'] = reporterPhone;

    // Debug: Print all fields being sent
    print('📤 Request fields:');
    request.fields.forEach((key, value) {
      print('   $key: "$value"');
    });

    if (imageFile != null) {
      print('📸 Adding image: ${imageFile.path}');
      
      if (await imageFile.exists()) {
        var stream = http.ByteStream(imageFile.openRead());
        var length = await imageFile.length();
        
        var multipartFile = http.MultipartFile(
          'image',
          stream,
          length,
          filename: imageFile.path.split('/').last,
        );
        request.files.add(multipartFile);
        print('📸 Image added, size: $length bytes');
      } else {
        print('⚠️ Image file does not exist');
      }
    }

    // Send request with timeout
    print('⏳ Sending request to ${request.url}...');
    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Connection timeout');
      },
    );
    
    var response = await http.Response.fromStream(streamedResponse);
    
    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');

    // Parse response
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      print('❌ Failed to parse response: $e');
      return {
        'success': false,
        'message': 'Invalid server response',
      };
    }

    // Return based on response
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        'message': data['message'] ?? 'Reported successfully',
        'id': data['id'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? data['error'] ?? 'Failed to report (${response.statusCode})',
      };
    }
  } catch (e) {
    print('❌ Exception in reportItem: $e');
    return {
      'success': false,
      'message': 'Network error: ${e.toString()}',
    };
  }
}


}
