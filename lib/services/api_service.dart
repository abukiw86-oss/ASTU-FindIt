import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../services/auth_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path; 


class ApiService {
  static const String baseUrl = "https://astufindit.x10.mx/index/api.php"; 

static Future<Map<String, dynamic>> register({
  required String email,
  required String password,
  required String fullName,
  String? phone,
}) async {
  try {
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
      // IMPORTANT: Save the user data including user_string_id
      if (data['user'] != null) {
        await AuthService.saveUser(
          userStringId: data['user']['user_string_id'],
          email: data['user']['email'],
          fullName: data['user']['full_name'],
          phone: data['user']['phone'],
          role: data['user']['role'],
        );
      }
      
      return {
        'success': true, 
        'message': data['message'] ?? 'Registered',
        'user': data['user']
      };
    } else {
      return {
        'success': false,
        'message': data['error'] ?? 'Registration failed',
        'status': response.statusCode,
      };
    }
  } catch (e) {
    return {'success': false, 'message': 'Network error: $e'};
  }
}
static Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl?action=login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['message'] == 'Logged in successfully') {
      if (data['user'] != null) {
        await AuthService.saveUser(
          userStringId: data['user']['user_string_id'], 
          email: data['user']['email'],
          fullName: data['user']['full_name'],
          phone: data['user']['phone'],
          role: data['user']['role'],
        );
      }
      
      return {
        'success': true,
        'user': data['user'],
        'message': 'Login successful',
      };
    } else {
      return {
        'success': false,
        'message': data['error'] ?? data['message'] ?? 'Login failed',
        'status': response.statusCode,
      };
    }
  } catch (e) {
    return {'success': false, 'message': 'Network error: $e'};
  }
}
  static Future<Map<String, dynamic>> getItems({required String type}) async {
    try {
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
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
// works
static Future<Map<String, dynamic>> reportlostItem({
  required String type,
  required String title,
  required String description,
  String? location,
  String? category,
  List<File>? imageFiles,
  required String reporterName,
  required String reporterPhone,
  String? userStringId,
}) async {
  try {
    print("Starting lost/found item report request");

    String finalType = type.trim().toLowerCase();
    if (finalType.isEmpty || (finalType != 'lost' && finalType != 'found')) {
      finalType = 'lost';
    }

    // Basic client-side validations
    if (title.trim().isEmpty) {
      return {'success': false, 'message': 'Title is required'};
    }
    if (description.trim().isEmpty) {
      return {'success': false, 'message': 'Description is required'};
    }
    if (reporterName.trim().isEmpty) {
      return {'success': false, 'message': 'Reporter name is required'};
    }
    if (reporterPhone.trim().isEmpty) {
      return {'success': false, 'message': 'Reporter phone is required'};
    }

    // For found items → require at least one image
    if (finalType == 'found' && (imageFiles == null || imageFiles.isEmpty)) {
      return {'success': false, 'message': 'At least one image is required for found items'};
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl?action=report-lost-item'),
    );

    request.headers['Accept'] = 'application/json';

    // Text fields
    request.fields.addAll({
      'type': finalType,
      'title': title.trim(),
      'description': description.trim(),
      'location': location?.trim() ?? '',
      'category': category?.trim() ?? 'other',
      'reporter_name': reporterName.trim(),
      'reporter_phone': reporterPhone.trim(),
    });

    if (userStringId != null && userStringId.isNotEmpty) {
      request.fields['user_string_id'] = userStringId;
    }

    // ── Add multiple images ───────────────────────────────────────────────
    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (var file in imageFiles) {
        if (!await file.exists()) {
          print('File does not exist: ${file.path}');
          continue;
        }

        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          print('Skipping large file: ${file.path} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');
          continue;
        }

        var multipartFile = http.MultipartFile(
          'image[]',  // ← IMPORTANT: use 'image' (no [])
          http.ByteStream(file.openRead()),
          fileSize,
          filename: path.basename(file.path),
        );

        request.files.add(multipartFile);
        print('Attached image: ${path.basename(file.path)} (${(fileSize / 1024).toStringAsFixed(0)} KB)');
      }
    }

    print("Sending request with ${request.files.length} image(s)");

    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout - check connection'),
    );

    var response = await http.Response.fromStream(streamedResponse);

    print('Response status: ${response.statusCode}');
    print('Response body (first 500 chars): ${response.body.substring(0, response.body.length.clamp(0, 5000))}');

    if (response.body.trim().isEmpty) {
      return {'success': false, 'message': 'Empty response from server'};
    }

    if (response.body.trim().startsWith('<')) {
      return {
        'success': false,
        'message': 'Server returned HTML (possible PHP error or misconfiguration)',
      };
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Invalid JSON response from server',
      };
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        'message': data['message'] ?? 'Item reported successfully',
        'id': data['id'],
        'item_string_id': data['item_string_id'],
        'uploaded_images': data['uploaded_images'] ?? 0,
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Server error (${response.statusCode})',
      };
    }
  } catch (e, stack) {
    print('Error in reportlostItem: $e');
    print('Stack trace: $stack');
    return {
      'success': false,
      'message': 'Request failed: ${e.toString()}',
    };
  }
}
// works
static Future<Map<String, dynamic>> getLostItems() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-lost-items'),
      );
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response'};
      }
      
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return {
          'success': true,
          'items': data['items'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load lost items',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

static Future<Map<String, dynamic>> requestItem({
    required String userStringId, 
    required int itemId,
    required String message,
    required String proof,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=request-item'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_string_id': userStringId, 
          'item_id': itemId,
          'message': message,
          'proof_description': proof,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

static Future<Map<String, dynamic>> getFoundItems({String? userStringId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-found-items${userStringId != null ? '&user_string_id=$userStringId' : ''}'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

static Future<Map<String, dynamic>> getUserRequests({required String userStringId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-requests&user_string_id=$userStringId'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update an existing item (only possible when status is 'pending')
  static Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required String title,
    required String description,
    String? location,
    required String category,
    File? imageFile,
    required String userStringId, // Changed from userId
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl?action=update-item'),
      );

      // Add text fields
      request.fields['item_id'] = itemId.toString();
      request.fields['user_string_id'] = userStringId; // Use string ID
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['location'] = location ?? '';
      request.fields['category'] = category;

      // Add image if provided
      if (imageFile != null) {
        if (await imageFile.exists()) {
          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          
          // Determine mime type based on file extension
          String mimeType = 'image/jpeg';
          if (imageFile.path.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (imageFile.path.toLowerCase().endsWith('.gif')) {
            mimeType = 'image/gif';
          } else if (imageFile.path.toLowerCase().endsWith('.jpg') || 
                     imageFile.path.toLowerCase().endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
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

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet.');
        },
      );
      
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.body.trim().isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }
      
      if (response.body.trim().startsWith('<')) {
        return {
          'success': false, 
          'message': 'Server error. Please check server logs.'
        };
      }
      
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
      
    } on SocketException {
      return {
        'success': false, 
        'message': 'No internet connection. Please check your network.'
      };
    } on HttpException {
      return {
        'success': false, 
        'message': 'Server connection failed. Please try again.'
      };
    } on FormatException catch (e) {
      return {
        'success': false, 
        'message': 'Invalid server response format.'
      };
    } catch (e) {
      return {
        'success': false, 
        'message': 'Error: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> deleteItem({
    required int itemId,
    required String userStringId, 
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=delete-item'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'item_id': itemId,
          'user_string_id': userStringId, // Use string ID
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet.');
        },
      );
      if (response.body.trim().isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }
      
      if (response.body.trim().startsWith('<')) {
        return {
          'success': false, 
          'message': 'Server error. Please check server logs.'
        };
      }
      
      return jsonDecode(response.body);
      
    } catch (e) {
      return {
        'success': false, 
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Profile-related methods using string ID
  static Future<Map<String, dynamic>> getUserProfile({required String userStringId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-profile&user_string_id=$userStringId'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required String userStringId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_string_id': userStringId,
          'full_name': fullName,
          'phone': phone,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String userStringId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_string_id': userStringId,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getUserHistory({required String userStringId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-user-history&user_string_id=$userStringId'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Notification methods using string ID
  static Future<Map<String, dynamic>> getNotifications({required String userStringId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get-notifications&user_string_id=$userStringId'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead({
    required int notificationId,
    required String userStringId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=mark-notification-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notification_id': notificationId,
          'user_string_id': userStringId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead({required String userStringId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=mark-all-notifications-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_string_id': userStringId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  // Add these helper methods to convert between ID types if needed
static String? getItemStringId(dynamic item) {
  if (item == null) return null;
  if (item is Map && item.containsKey('item_string_id')) {
    return item['item_string_id'] as String?;
  }
  return null;
}

// Update requestItemAccess to accept itemStringId
static Future<Map<String, dynamic>> requestItemAccess({
  required String userStringId,
  required dynamic itemId, // Can be int or String
  required String message,
}) async {
  try {
    Map<String, dynamic> body = {
      'user_string_id': userStringId,
      'message': message,
    };
    
    // Handle both numeric and string IDs
    if (itemId is String) {
      body['item_string_id'] = itemId;
    } else {
      body['item_id'] = itemId;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl?action=request-item-access'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Connection timeout'),
    );
    
    if (response.body.trim().isEmpty) {
      return {'success': false, 'message': 'Empty response from server'};
    }
    
    if (response.body.trim().startsWith('<')) {
      return {
        'success': false, 
        'message': 'Server error. Please check server logs.'
      };
    }
    
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data;
    
  } catch (e) {
    return {
      'success': false, 
      'message': 'Network error: ${e.toString()}'
    };
  }
}

static Future<Map<String, dynamic>> getItemByStringId(String itemStringId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl?action=get-item&item_string_id=$itemStringId'),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Connection timeout'),
    );

    if (response.body.isEmpty) {
      return {'success': false, 'message': 'Empty response'};
    }

    final data = jsonDecode(response.body);
    
    if (data['success'] == true) {
      return {
        'success': true,
        'item': data['item'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Item not found',
      };
    }
  } catch (e) {
    return {'success': false, 'message': 'Network error: $e'};
  }
}

static Future<Map<String, dynamic>> reportFoundMatch({
  required String lostItemStringId,
  required String finderName,
  required String finderPhone,
  required String finderMessage,
 required String userStringId,
 required List<File>? imageFiles,         
}) async {
  try {
    print('📤 Reporting found match for lost item: $lostItemStringId');
    print(userStringId);
    print('   Images to upload: ${imageFiles?.length ?? 0}');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl?action=report-found-match'),
    );

    // ── Text fields ────────────────────────────────────────
    request.fields['lost_item_string_id'] = lostItemStringId;
    request.fields['finder_name']         = finderName;
    request.fields['finder_phone']        = finderPhone;
    request.fields['finder_message']      = finderMessage;
    request.fields['user_string_id']      =  userStringId ;
    // ── Multiple images ────────────────────────────────────
    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (var i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];

        if (await file.exists()) {
          final length = await file.length();
          final filename = file.path.split(Platform.pathSeparator).last;

          if (length > 8 * 1024 * 1024) { 
            print('⚠️ Skipping large file: $filename (${(length / 1024 / 1024).toStringAsFixed(1)} MB)');
            continue;
          }

          var stream = http.ByteStream(file.openRead());

          var multipartFile = http.MultipartFile(
            'image[]',          
            stream,
            length,
            filename: filename,
          );

          request.files.add(multipartFile);
          print('📸 Added image ${i + 1}/${imageFiles.length}: $filename (${(length / 1024).toStringAsFixed(0)} KB)');
        } else {
          print('⚠️ File not found: ${file.path}');
        }
      }
    }

    // ── Send request ───────────────────────────────────────
    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),   // ← increased a bit because multiple images take longer
      onTimeout: () => throw Exception('Upload timeout'),
    );

    var response = await http.Response.fromStream(streamedResponse);

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body.substring(0, response.body.length.clamp(0, 5000))}...');

    if (response.body.trim().isEmpty) {
      return {'success': false, 'message': 'Empty response from server'};
    }

    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (jsonErr) {
      return {
        'success': false,
        'message': 'Invalid JSON response: ${response.body}',
      };
    }

  } catch (e, stack) {
    print('❌ Error in reportFoundMatch: $e');
    print('Stack trace: $stack');
    return {
      'success': false,
      'message': 'Network/upload error: ${e.toString()}',
    };
  }
}

static Future<Map<String, dynamic>> getItemDetails({required String itemStringId}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl?action=get-item&item_string_id=$itemStringId'),
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