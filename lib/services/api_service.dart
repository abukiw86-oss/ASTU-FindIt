import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../services/auth_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path; 


class ApiService {
  static const String baseUrl = "https://astufindit.x10.mx/index/api.php"; 

static Future<Map<String, dynamic>> register({
  required String student_id,
  required String password,
  required String fullName,
  String? phone,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl?action=register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': student_id,
        'password': password,
        'full_name': fullName,
        'phone': phone ?? '',
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      if (data['user'] != null) {
        await AuthService.saveUser(
          userStringId: data['user']['user_string_id'],
          student_id: data['user']['student_id'],
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
  required String studentId,
  required String password,
}) async {
  try {
    final uri = Uri.parse('$baseUrl?action=login');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'student_id': studentId,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) { 
      return {
        'success': false,
        'message': data['message'],
        'status': response.statusCode,
      };
    }
    
    if (data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>?;

      if (user != null) {
        await AuthService.saveUser(
          userStringId: user['user_string_id'] as String? ?? '',
          student_id: user['student_id'] as String? ?? '',
          fullName: user['full_name'] as String? ?? '',
          phone: user['phone'] as String? ?? '',
          role: user['role'] as String? ?? 'student',
        );
      }

      return {
        'success': true,
        'user': user,
        'message': data['message'] ?? 'Login successful',
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? data['error'] ?? 'Login failed',
        'status': response.statusCode,
      };
    }
  } catch (e) { 
    return {
      'success': false,
      'message': 'Network or login error: $e',
    };
  }
} 

static Future<Map<String, dynamic>> reportlostItem({
  required String type,
  required String title,
  required String description,
  String? location,
  String? category,
  List<File>? imageFiles,
  required String reporterName,
  required String reporterPhone,
  required String userStringId,
}) async {
  try {
    String finalType = type.trim().toLowerCase();
    if (finalType.isEmpty || (finalType != 'lost' && finalType != 'found')) {
      finalType = 'lost';
    }
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
    if (finalType == 'found' && (imageFiles == null || imageFiles.isEmpty)) {
      return {'success': false, 'message': 'At least one image is required for found items'};
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl?action=report-lost-item'),
    );

    request.headers['Accept'] = 'application/json';
 
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
    }else{
      return {
        'success': false,
        'message': 'please sign in/ register',
      };
    }

    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (var file in imageFiles) {
        if (!await file.exists()) {
          continue;
        }

        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          continue;
        }

        var multipartFile = http.MultipartFile(
          'image[]',
          http.ByteStream(file.openRead()),
          fileSize,
          filename: path.basename(file.path),
        );

        request.files.add(multipartFile);}
    }
    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout - check connection'),
    );

    var response = await http.Response.fromStream(streamedResponse);
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
  } catch (e) {
    return {
      'success': false,
      'message': 'Request failed: ${e.toString()}',
    };
  }
}
 
static Future<Map<String, dynamic>> getLostItems({String? userStringId}) async {
  try {
    String url = '$baseUrl?action=get-lost-items'; 
    if (userStringId != null && userStringId.isNotEmpty) {
      url += '&user_string_id=$userStringId';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Connection timeout'),
    );
    if (response.body.isEmpty) {
      return {'success': false, 'message': 'Empty response from server'};
    }
     
    if (response.statusCode != 200) {
      return {
        'success': false, 
        'message': 'Server error: ${response.statusCode}'
      };
    }
    
    final Map<String, dynamic> data = jsonDecode(response.body);
     
    if (data['success'] == true) {
      List<dynamic> items = data['items'] ?? [];
       
      List<Map<String, dynamic>> processedItems = [];
      
      for (var item in items) {
        Map<String, dynamic> processedItem = Map<String, dynamic>.from(item);
         
        if (processedItem.containsKey('image_path') && 
            processedItem['image_path'] != null && 
            processedItem['image_path'] != 'NULL') {
           
          String imagePath = processedItem['image_path'].toString();
          if (imagePath.contains('|')) {
            processedItem['image_list'] = imagePath.split('|')
                .where((url) => url.trim().isNotEmpty)
                .toList();
          } else if (imagePath.isNotEmpty) {
            processedItem['image_list'] = [imagePath];
          } else {
            processedItem['image_list'] = [];
          }
        } else {
          processedItem['image_list'] = [];
        } 
        processedItem['is_my_item'] = processedItem['is_my_item'] == true || 
                                       processedItem['is_my_item'] == '1';
        
        processedItems.add(processedItem);
      } 
      return {
        'success': true,
        'items': processedItems,
        'user_items': data['user_items'] ?? [],
        'other_items': data['other_items'] ?? [],
        'user_info': data['user_info'] ?? {},
        'totals': data['totals'] ?? {},
        'has_admin_approval': data['user_info']?['has_admin_approval'] ?? false,
        'admin_approval_count': data['user_info']?['admin_approval_count'] ?? 0,
        'message': data['message'] ?? 'Items loaded successfully',
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to load lost items',
      };
    }
  } on SocketException catch (e) {
    return {
      'success': false, 
      'message': 'Network error: Please check your internet connection'
    };
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


static Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required String title,
    required String description,
    String? location,
    required String category,
    File? imageFile,
    required String userStringId, 
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl?action=update-item'),
      );
      request.fields['item_id'] = itemId.toString();
      request.fields['user_string_id'] = userStringId; 
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['location'] = location ?? '';
      request.fields['category'] = category;

      if (imageFile != null) {
        if (await imageFile.exists()) {
          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          
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
          'user_string_id': userStringId,
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


static Future<Map<String, dynamic>> requestItemAccess({
  required String userStringId,
  required dynamic itemId, 
  required String message,
}) async {
  try {
    if (userStringId.isEmpty) {
      return {'success': false, 'message': 'User ID is required'};
    }
    
    if (itemId == null || itemId.toString().isEmpty) {
      return {'success': false, 'message': 'Item ID is required'};
    }
    
    if (message.length < 20) {
      return {'success': false, 'message': 'Message must be at least 20 characters'};
    }

    Map<String, dynamic> body = {
      'user_string_id': userStringId,
      'item_string_id': itemId.toString(), 
      'message': message.trim(),
    };
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
    if (response.body.isEmpty) {
      return {'success': false, 'message': 'Empty response from server'};
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

static Future<Map<String, dynamic>> reportFoundMatch({
  required String lostItemStringId, 
  required String finderName,
  required String finderPhone,
  required String finderMessage,
  required String userStringId,
  required List<File>? imageFiles,  
  required String properties,
  required String location ,
  required String foundDate,
  required String title      
}) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl?action=report-found-match'),
    );
    request.fields['title'] = title;
    request.fields['location']         = location;
    request.fields['date_and_time']        = foundDate;
    request.fields['property']      = properties;
    request.fields['lost_item_string_id'] = lostItemStringId;
    request.fields['finder_name']         = finderName;
    request.fields['finder_phone']        = finderPhone;
    request.fields['finder_message']      = finderMessage;
    request.fields['user_string_id']      =  userStringId ;

    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (var i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];

        if (await file.exists()) {
          final length = await file.length();
          final filename = file.path.split(Platform.pathSeparator).last;

          if (length > 8 * 1024 * 1024) { 
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
        }
      }
    }
    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 45), 
      onTimeout: () => throw Exception('Upload timeout'),
    );

    var response = await http.Response.fromStream(streamedResponse);

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
