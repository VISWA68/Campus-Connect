import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/student_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MyEventsPage extends StatefulWidget {
  const MyEventsPage({Key? key}) : super(key: key);

  @override
  _MyEventsPageState createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  List<Map<String, dynamic>> registeredEvents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRegisteredEvents();
  }

  Future<void> fetchRegisteredEvents() async {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final email = studentProvider.email;

    if (email == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://192.168.219.231:5000/get_registered_events/$email'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          registeredEvents = List<Map<String, dynamic>>.from(data['events']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch registered events');
      }
    } catch (e) {
      print('Error fetching registered events: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching events: $e')),
        );
      }
    }
  }

  Future<String?> _getQrData(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('qr_$eventId');
    } catch (e) {
      print('Error getting QR data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : registeredEvents.isEmpty
              ? const Center(child: Text('No registered events'))
              : ListView.builder(
                  itemCount: registeredEvents.length,
                  itemBuilder: (context, index) {
                    final event = registeredEvents[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ExpansionTile(
                        title: Text(event['event_name'] ?? 'Unknown Event'),
                        subtitle: Text('Date: ${event['start_date'] ?? 'TBA'}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                FutureBuilder<String?>(
                                  future: _getQrData(event['event_id']),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const CircularProgressIndicator();
                                    }
                                    
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Column(
                                        children: [
                                          QrImageView(
                                            data: snapshot.data!,
                                            version: QrVersions.auto,
                                            size: 200,
                                            backgroundColor: Colors.white,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Show this QR code at the event',
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    
                                    return const Text(
                                      'QR code not available',
                                      style: TextStyle(color: Colors.red),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text('Organized by: ${event['organized_by'] ?? 'Unknown'}'),
                                Text('Description: ${event['description'] ?? 'No description'}'),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: event['attendance_marked'] == true
                                        ? Colors.green[100]
                                        : Colors.red[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    event['attendance_marked'] == true
                                        ? 'Attendance Marked'
                                        : 'Attendance Not Marked',
                                    style: TextStyle(
                                      color: event['attendance_marked'] == true
                                          ? Colors.green[900]
                                          : Colors.red[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
