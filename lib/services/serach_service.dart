import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lost_found_app/services/api_service.dart';
class search{
static Future<Map<String, dynamic>> simpleSearch({
  required String query,
  String type = 'all',
  String? userId,
}) async {
  try {
    final queryParams = <String, String>{
      'action': 'simple-search',
      'query': query,
      if (type != 'all') 'type': type,
      if (userId != null) 'user_id': userId,
    };

    final uri = Uri.parse('${ApiService.baseUrl}?${Uri(queryParameters: queryParams).query}');
    
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'message': 'Search failed'};
  } catch (e) {
    return {'success': false, 'message': 'Network error'};
  }
}
static Future<Map<String, dynamic>> getSimpleItemDetails(int itemId) async {
  try {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}?action=simple-item-details&id=$itemId'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'message': 'Failed to load item details'};
  } catch (e) {
    return {'success': false, 'message': 'Network error'};
  }
}
}