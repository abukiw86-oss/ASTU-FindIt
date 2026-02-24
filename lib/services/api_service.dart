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
  required int? userId, 
}) async {
  try {
    String finalType = type.trim().toLowerCase();
    if (finalType.isEmpty) {
      finalType = 'lost';
    }
    
    if (finalType != 'lost' && finalType != 'found') {
      finalType = 'lost';
    }
    
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl?action=report-item'),
    );

    request.fields['type'] = finalType; 
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['location'] = location ?? '';
    request.fields['category'] = category ?? 'other';
    request.fields['reporter_name'] = reporterName;
    request.fields['reporter_phone'] = reporterPhone;
     if (userId != null) {
      request.fields['user_id'] = userId.toString();
    }

    if (imageFile != null) {
      
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
      }
    }

    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Connection timeout');
      },
    );
    
    var response = await http.Response.fromStream(streamedResponse);
    
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
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
    return {
      'success': false,
      'message': 'Network error: ${e.toString()}',
    };
  }
}
static Future<Map<String, dynamic>> getLostItems() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl?action=get-lost-items'),
    );
    final data = jsonDecode(response.body);
    return data;
  } catch (e) {
    return {'success': false, 'message': 'Network error'};
  }
}


static Future<Map<String, dynamic>> requestItem({
  required int userId,
  required int itemId,
  required String message,
  required String proof,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl?action=request-item'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
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
static Future<Map<String, dynamic>> reportFoundMatch({
  required int lostItemId,
  required String finderName,
  required String finderPhone,
  required String finderMessage,
  int? userId,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl?action=report-found-match'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'lost_item_id': lostItemId,
        'finder_name': finderName,
        'finder_phone': finderPhone,
        'finder_message': finderMessage,
        'user_id': userId,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Connection timeout');
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
    
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data;
    
  } catch (e) {
    return {
      'success': false, 
      'message': 'Network error: ${e.toString()}'
    };
  }
}

static Future<Map<String, dynamic>> requestItemAccess({
  required int userId,
  required int itemId,
  required String message,
}) async {
  try {
    
    final response = await http.post(
      Uri.parse('$baseUrl?action=request-item-access'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'item_id': itemId,
        'message': message,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Connection timeout');
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
    
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data;
    
  } catch (e) {
    return {
      'success': false, 
      'message': 'Network error: ${e.toString()}'
    };
  }
}
static Future<Map<String, dynamic>> getFoundItems({int? userId}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl?action=get-found-items${userId != null ? '&user_id=$userId' : ''}'),
    );
    return jsonDecode(response.body);
  } catch (e) {
    return {'success': false, 'message': 'Network error: $e'};
  }

}
static Future<Map<String, dynamic>> getUserRequests({required int userId}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl?action=get-user-requests&user_id=$userId'),
    );
    return jsonDecode(response.body);
  } catch (e) {
    return {'success': false, 'message': 'Network error: $e'};
  }
}

}
