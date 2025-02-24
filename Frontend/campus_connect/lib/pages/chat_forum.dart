import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/public_chat_provider.dart';
import '../providers/student_provider.dart';

class ChatForumPage extends StatefulWidget {
  @override
  _ChatForumPageState createState() => _ChatForumPageState();
}

class _ChatForumPageState extends State<ChatForumPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Provider.of<PublicChatProvider>(context, listen: false).fetchMessages();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _reportMessage(String userId, String message) async {
    final url = Uri.parse('http://192.168.219.231:5000/report_message');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'message': message}),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message reported successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to report message.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<PublicChatProvider>(context);
    final studentProvider = Provider.of<StudentProvider>(context);
    final studentId = studentProvider.studentId ?? "unknown";
    final bool isAnonymous = studentProvider.isAnonymous;
    final studentName = isAnonymous
        ? "Anonymous"
        : studentProvider.currentStudent?.name ?? "User";

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        title: const Text("Chat Forum"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              chatProvider.fetchMessages();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: chatProvider.messageStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No messages yet.'));
          }

          final messages = snapshot.data!;

          return ListView.builder(
            controller: _scrollController,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final bool isMe = msg['sender_id'] == studentId;
              final time =
                  DateTime.parse(msg['timestamp'] ?? DateTime.now().toString());
              final timeString = DateFormat('hh:mm a').format(time);

              return GestureDetector(
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Report Message'),
                        content: const Text(
                            'Do you want to report this message as inappropriate?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              _reportMessage(msg['sender_id'], msg['message']);
                              Navigator.of(context).pop();
                            },
                            child: const Text('Report'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isMe ? Theme.of(context).primaryColor : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender_name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          msg['message'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Enter your message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                if (_messageController.text.trim().isNotEmpty) {
                  final message = _messageController.text.trim();
                  chatProvider.sendMessage(
                    studentId,
                    studentName,
                    message,
                  ).then((response) {
                    if (response != null && response.containsKey('toxicity')) {
                      final toxicity = response['toxicity'];
                      if (toxicity['label'] != 'Neutral') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Your message was flagged as ${toxicity['label']}. It has been automatically reported.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  });
                  _messageController.clear();
                  _scrollToBottom();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
