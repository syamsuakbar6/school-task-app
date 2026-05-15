enum UserRole {
  student,
  teacher,
  admin;

  static UserRole fromJson(String value) {
    return switch (value.toLowerCase().trim()) {
      'teacher' => teacher,
      'admin' => admin,
      _ => student,
    };
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.nisn,
    this.nip,
  });

  final int id;
  final String name;
  final String? email;
  final String? nisn;
  final String? nip;
  final UserRole role;

  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  bool get isAdmin => role == UserRole.admin;

  /// Identifier yang dipakai login — NISN untuk siswa, NIP untuk guru/admin
  String get identifier => isStudent ? (nisn ?? '') : (nip ?? '');

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      nisn: json['nisn'] as String?,
      nip: json['nip'] as String?,
      role: UserRole.fromJson(json['role'] as String? ?? 'student'),
    );
  }
}
