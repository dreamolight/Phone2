import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {
  static const String baseUrl = 'http://marsmobile.com:3000'; // Change to IP if real device
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return data;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return data;
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  Future<void> uploadLogs(List<Map<String, dynamic>> logs) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/sync/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'logs': logs}),
    );

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.body}');
    }
  }

  Future<List<dynamic>> fetchLogs({int limit = 100, int offset = 0}) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/sync/fetch?limit=$limit&offset=$offset'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Fetch failed: ${response.body}');
    }
  }

  Future<List<dynamic>> fetchConversations({String? category}) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    String url = '$baseUrl/sync/conversations';
    if (category != null) {
      url += '?category=$category';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Fetch conversations failed [${response.statusCode}]: ${response.body}');
    }
  }

  Future<List<dynamic>> fetchMessages(String remoteNumber) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    // Use Uri constructor to handle query parameter encoding (e.g. '+' -> '%2B')
    final uri = Uri.parse('$baseUrl/sync/messages').replace(queryParameters: {
      'remote_number': remoteNumber,
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Fetch messages failed: ${response.body}');
    }
  }

  Future<void> markRead(String remoteNumber) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/sync/mark_read'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'remote_number': remoteNumber}),
    );

    if (response.statusCode != 200) {
      throw Exception('Mark read failed: ${response.body}');
    }
  }

  Future<Map<String, int>> fetchUnreadCounts() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/sync/unread_counts'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'messages': data['messages'] ?? 0,
        'calls': data['calls'] ?? 0,
      };
    } else {
      throw Exception('Fetch unread counts failed: ${response.body}');
    }
  }

  Future<void> markCategoryRead(String category) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/sync/mark_category_read'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'category': category}),
    );

    if (response.statusCode != 200) {
      throw Exception('Mark category read failed: ${response.body}');
    }
  }

  Future<void> sendCommand(String type, Map<String, dynamic> payload) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/sync/command'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'type': type, 'payload': payload}),
    );

    if (response.statusCode != 200) {
      throw Exception('Command failed: ${response.body}');
    }
  }
}
