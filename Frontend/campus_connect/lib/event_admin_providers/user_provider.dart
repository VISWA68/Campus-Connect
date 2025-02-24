import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserProvider extends ChangeNotifier {
  String? adminEmail;
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> allEvents = [];
  List<Map<String, dynamic>> registeredParticipants = [];
  String? selectedEventId;
  String? error;

  Future<bool> loginAsAdmin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.219.231:5000/login_event_admin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        adminEmail = email;
        events = List<Map<String, dynamic>>.from(responseData['events'] ?? []);
        await fetchAllEvents(); // Fetch all events after successful login
        notifyListeners();
        return true;
      } else {
        error = responseData['error'] ?? 'Login failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      error = 'An error occurred: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshEvents() async {
    try {
      if (adminEmail == null) return;

      final response = await http.get(
        Uri.parse('http://192.168.219.231:5000/get_admin_events/$adminEmail'),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        events = List<Map<String, dynamic>>.from(responseData['events'] ?? []);
        notifyListeners();
      } else {
        error = responseData['error'] ?? 'Failed to fetch events';
        notifyListeners();
      }
    } catch (e) {
      error = 'An error occurred: $e';
      notifyListeners();
    }
  }

  Future<void> fetchAllEvents() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.219.231:5000/get_events'),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        allEvents = List<Map<String, dynamic>>.from(responseData['events'] ?? []);
        notifyListeners();
      } else {
        error = responseData['error'] ?? 'Failed to fetch all events';
        notifyListeners();
      }
    } catch (e) {
      error = 'An error occurred: $e';
      notifyListeners();
    }
  }

  Future<bool> createEvent({
    required String eventName,
    required String startDate,
    required String endDate,
    required String organizedBy,
    required String description,
    required String pricing,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.219.231:5000/create_event'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'event_name': eventName,
          'start_date': startDate,
          'end_date': endDate,
          'organized_by': organizedBy,
          'description': description,
          'pricing': pricing,
          'admin_email': adminEmail,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        final newEvent = responseData['event'];
        events.add(Map<String, dynamic>.from(newEvent));
        notifyListeners();
        return true;
      } else {
        error = responseData['error'] ?? 'Failed to create event';
        notifyListeners();
        return false;
      }
    } catch (e) {
      error = 'An error occurred: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchRegisteredParticipants(String eventId) async {
    try {
      selectedEventId = eventId;
      final response = await http.get(
        Uri.parse('http://192.168.219.231:5000/get_registered_participants/$eventId'),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        registeredParticipants = List<Map<String, dynamic>>.from(responseData['participants'] ?? []);
      } else {
        error = responseData['error'] ?? 'Failed to fetch participants';
      }
      notifyListeners();
    } catch (e) {
      error = 'An error occurred: $e';
      notifyListeners();
    }
  }

  void logout() {
    adminEmail = null;
    events.clear();
    allEvents.clear();
    registeredParticipants.clear();
    selectedEventId = null;
    error = null;
    notifyListeners();
  }
}