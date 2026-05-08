enum UserRole {
  student,
  teacher;

  static UserRole fromJson(String value) {
    return value.toLowerCase() == 'teacher' ? teacher : student;
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;

  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromJson(json['role'] as String? ?? 'student'),
    );
  }
}
