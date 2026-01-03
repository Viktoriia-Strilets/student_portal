class StudentProfile {
  final String fullName;
  final String group;
  final String specialty;
  final String email;
  final String studentId;
  final String description;
  final String? localPhotoPath;

  StudentProfile({
    required this.fullName,
    required this.group,
    required this.specialty,
    required this.email,
    required this.studentId,
    required this.description,
    required this.localPhotoPath,
  });

  factory StudentProfile.fromMap(Map<String, dynamic> map) {
    return StudentProfile(
      fullName: map['fullName'] ?? '',
      group: map['group'] ?? '',
      specialty: map['specialty'] ?? '',
      email: map['email'] ?? '',
      studentId: map['studentId'] ?? '',
      description: map['description'] ?? '',
      localPhotoPath: map['localPhotoPath'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'group': group,
      'specialty': specialty,
      'email': email,
      'studentId': studentId,
      'description': description,
      'localPhotoPath': localPhotoPath,
    };
  }
}
