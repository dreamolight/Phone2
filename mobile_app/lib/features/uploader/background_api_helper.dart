import 'dart:convert';
import 'package:http/http.dart' as http;

class BackgroundApiHelper {
  static const String baseUrl = 'http://192.168.68.89:3000'; 

  static Future<void> uploadLogs(String token, List<Map<String, dynamic>> logs) async {
    // ... (existing upload implementation) implies this file is NOT the service file but the helper.
    // Wait, I am editing background_api_helper.dart or background_service.dart?
    // I need to add methods to BackgroundApiHelper first.
    // Retaining existing code via context.
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/upload'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'logs': logs}),
      );
      if (response.statusCode != 200) {
        print('Upload failed: ${response.body}');
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload exception: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> fetchCommands(String token) async {
    try {
       final response = await http.get(
        Uri.parse('$baseUrl/sync/commands'),
        headers: {'Authorization': 'Bearer $token'},
       );
       if (response.statusCode == 200) {
         return jsonDecode(response.body);
       }
    } catch (e) {
      print('Fetch commands error: $e');
    }
    return [];
  }

  static Future<void> updateCommandStatus(String token, int commandId, String status) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/sync/command/$commandId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );
    } catch (e) {
      print('Update status error: $e');
    }
  }
  static Future<Map<String, int>> fetchLastTimestamps(String token) async {
    try {
       final response = await http.get(
        Uri.parse('$baseUrl/sync/status'),
        headers: {'Authorization': 'Bearer $token'},
       );
       if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         return {
           'lastSms': data['lastSmsTimestamp'] ?? 0,
           'lastCall': data['lastCallTimestamp'] ?? 0,
         };
       }
    } catch (e) {
      print('Fetch status error: $e');
    }
    return {'lastSms': 0, 'lastCall': 0};
  }
}
