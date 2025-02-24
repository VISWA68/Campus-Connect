import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class StudentProvider extends ChangeNotifier {
  Student? _currentStudent;
  String? _studentId;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  bool _isAnonymous = false; // Anonymous Chat Toggle

  Student? get currentStudent => _currentStudent;
  String? get studentId => _studentId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAnonymous => _isAnonymous;

  // Add getters for student details with null checks
  String? get name => _currentStudent?.name;
  String? get email => _currentStudent?.email;
  String? get rollNo => _currentStudent?.rollNo;

  // Helper method to check if student is logged in
  bool get isLoggedIn => _currentStudent != null;

  void toggleAnonymousMode(bool value) {
    _isAnonymous = value;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    setLoading(true);
    setError(null);

    try {
      final result = await _apiService.login(email, password);

      if (result['success']) {
        _studentId = result['studentId'];
        await fetchStudentDetails(); // Fetch full details after login
        setLoading(false);
        return true;
      } else {
        setError(result['message']);
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('An error occurred during login');
      setLoading(false);
      return false;
    }
  }

  Future<bool> registerStudent(
    String name,
    String email,
    String password,
    String rollNo,
  ) async {
    setLoading(true);
    setError(null);

    try {
      final result = await _apiService.register(
        name,
        rollNo,
        email,
        password,
      );

      setLoading(false);
      if (!result['success']) {
        setError(result['message']);
        return false;
      }
      return true;
    } catch (e) {
      setError('Registration failed: $e');
      setLoading(false);
      return false;
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String rollNo, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.register(
        name,
        rollNo,
        email,
        password,
      );

      _isLoading = false;
      if (!result['success']) {
        _error = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return {
        'success': false,
        'message': 'Registration failed: $e',
      };
    }
  }

  Future<void> fetchStudentDetails() async {
    if (_studentId == null) return;

    final studentData = await _apiService.getStudentDetails(_studentId!);

    if (studentData != null) {
      _currentStudent = Student(
        id: studentData['student_id'],
        rollNo: studentData['roll_no'] ?? studentData['student_id'],  // Fallback to student_id if roll_no not present
        name: studentData['name'],
        email: studentData['email'],
      );
      notifyListeners();
    } else {
      setError("Failed to fetch student details");
    }
  }

  void logout() {
    _currentStudent = null;
    _studentId = null;
    notifyListeners();
  }
}
