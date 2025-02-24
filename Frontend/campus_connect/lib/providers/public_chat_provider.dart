import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../providers/student_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class PublicChatProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final StreamController<List<Map<String, dynamic>>> _messageStreamController = StreamController.broadcast();

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  Stream<List<Map<String, dynamic>>> get messageStream => _messageStreamController.stream;

  Future<void> fetchMessages() async {
    _isLoading = true;
    notifyListeners();

    _messages = await _apiService.getMessages();
    _messageStreamController.add(_messages);
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> sendMessage(
      String senderId, String senderName, String message) async {
    final response =
        await _apiService.sendMessage(senderId, senderName, message);

    if (response.containsKey('message')) {
      fetchMessages();
      return response;
    }
    return null;
  }

  @override
  void dispose() {
    _messageStreamController.close();
    super.dispose();
  }
}
