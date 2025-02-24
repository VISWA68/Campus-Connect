import 'package:campus_connect/event_admin_pages/attendance_page.dart';
import 'package:flutter/material.dart';
import 'home.dart';
import 'registrations.dart';

class AdminBasePage extends StatefulWidget {
  @override
  _AdminBasePageState createState() => _AdminBasePageState();
}

class _AdminBasePageState extends State<AdminBasePage> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    //EventAdminHomePage(),
    RegistrationsPage(),
   // AttendancePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Registrations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Attendance',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}
