import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.219.231:5000';

  Future<Map<String, dynamic>> register(
      String name, String rollNo, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "name": name,
          "roll_no": rollNo,
          "email": email,
          "password": password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'],
          'studentId': responseData['student_id'], // This will be the ObjectId
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "email": email,
          "password": password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'studentId': responseData['student_id'], // This will be the ObjectId
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  Future<Map<String, dynamic>> sendMessage(
      String senderId, String senderName, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send_message'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "sender_id": senderId,
          "sender_name": senderName,
          "message": message,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'message': responseData['message'],
          'toxicity': responseData['toxicity'],
        };
      } else {
        return {
          'error': responseData['error'] ?? 'Message sending failed'
        };
      }
    } catch (e) {
      return {'error': 'An error occurred: $e'};
    }
  }

  // Fetch messages
  Future<List<Map<String, dynamic>>> getMessages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_messages'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['messages']);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

    Future<Map<String, dynamic>?> getStudentDetails(String studentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_student/$studentId'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
