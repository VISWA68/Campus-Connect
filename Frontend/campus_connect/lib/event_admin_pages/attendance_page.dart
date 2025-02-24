import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../event_admin_providers/user_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendancePage extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AttendancePage({
    Key? key,
    required this.eventId,
    required this.eventName,
  }) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Map<String, dynamic>> registrations = [];
  bool isScanning = false;
  bool isLoading = true;
  final MobileScannerController controller = MobileScannerController();

  @override
  void initState() {
    super.initState();
    fetchRegistrations();
  }

  Future<void> fetchRegistrations() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.219.231:5000/get_event_registrations/${widget.eventId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          registrations = List<Map<String, dynamic>>.from(data['registrations']);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching registrations: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> markAttendance(String email) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.219.231:5000/mark_attendance'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'event_id': widget.eventId,
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        // Refresh the registrations list
        fetchRegistrations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance marked successfully')),
        );
      }
    } catch (e) {
      print('Error marking attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking attendance: $e')),
      );
    }
  }

  void onQRCodeDetected(String? qrData) {
    if (qrData != null) {
      try {
        final data = json.decode(qrData);
        if (data['event_id'] == widget.eventId) {
          markAttendance(data['email']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid QR code for this event')),
          );
        }
      } catch (e) {
        print('Error processing QR code: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.eventName}'),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.qr_code_scanner),
            onPressed: () {
              setState(() {
                isScanning = !isScanning;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (isScanning)
            SizedBox(
              height: 300,
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    onQRCodeDetected(barcode.rawValue);
                  }
                },
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: registrations.length,
                    itemBuilder: (context, index) {
                      final registration = registrations[index];
                      final bool isPresent = registration['attendance_marked'] == true;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        color: isPresent ? Colors.green[50] : Colors.red[50],
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPresent ? Colors.green : Colors.red,
                            child: Icon(
                              isPresent ? Icons.check : Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(registration['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${registration['email']}'),
                              Text('Roll No: ${registration['roll_no']}'),
                              Text(
                                isPresent ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: isPresent ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
