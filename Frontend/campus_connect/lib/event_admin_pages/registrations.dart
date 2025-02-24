import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../event_admin_providers/user_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class RegistrationsPage extends StatefulWidget {
  @override
  _RegistrationsPageState createState() => _RegistrationsPageState();
}

class _RegistrationsPageState extends State<RegistrationsPage> {
  String? selectedEventId;
  List<Map<String, dynamic>> registrations = [];
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final events = userProvider.events;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Registrations'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          // Event Dropdown
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: selectedEventId,
              decoration: const InputDecoration(
                labelText: 'Select Event',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var event in events)
                  DropdownMenuItem<String>(
                    value: event['event_id']?.toString() ?? '',
                    child: Text(event['event_name']?.toString() ?? 'Unknown Event'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedEventId = value;
                    fetchRegistrations(value);
                  });
                }
              },
            ),
          ),
          // Registrations List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : selectedEventId == null
                    ? const Center(child: Text('Please select an event'))
                    : registrations.isEmpty
                        ? const Center(child: Text('No registrations yet'))
                        : ListView.builder(
                            itemCount: registrations.length,
                            itemBuilder: (context, index) {
                              final registration = registrations[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      registration['name']
                                              ?.toString()
                                              .substring(0, 1)
                                              .toUpperCase() ??
                                          'S',
                                    ),
                                  ),
                                  title: Text(registration['name']?.toString() ?? 'Unknown'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Email: ${registration['email']?.toString() ?? 'N/A'}'),
                                      Text('Roll No: ${registration['roll_no']?.toString() ?? 'N/A'}'),
                                      Text(
                                        'Registered: ${_formatDate(registration['registered_at']?.toString())}',
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> fetchRegistrations(String eventId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://192.168.219.231:5000/get_event_registrations/$eventId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          registrations = List<Map<String, dynamic>>.from(
            data['registrations'] ?? [],
          );
        });
      } else {
        throw Exception('Failed to load registrations');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading registrations: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}