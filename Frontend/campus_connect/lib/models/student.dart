class Student {
  final String id;
  final String name;
  final String email;
  final String rollNo;  // Added roll number
  final String? password;
  final DateTime? createdAt;

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.rollNo,  // Added to constructor
    this.password,
    this.createdAt,
  });

  // Factory constructor to create a Student from JSON
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['student_id'] ?? '', // Ensures id is not null
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? 'No Email',
      rollNo: json['roll_no'] ?? '',  // Get roll number from JSON
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) // Prevents crashes
          : null,
    );
  }

  // Convert Student instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'student_id': id,
      'name': name,
      'email': email,
      'roll_no': rollNo,  // Include roll number in JSON
      if (password != null) 'password': password, // Only include if present
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
