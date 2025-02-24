import 'package:campus_connect/event_admin_providers/user_provider.dart';
import 'package:campus_connect/providers/public_chat_provider.dart';
import 'package:campus_connect/providers/student_provider.dart';
import 'package:flutter/material.dart';
import 'package:campus_connect/pages/login_page.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => PublicChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: CampusConnectApp(),
    ),
  );
}

class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Connect',
      home: LoginPage(),
    );
  }
}
