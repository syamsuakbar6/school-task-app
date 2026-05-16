import 'app_user.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.isClosed,
    required this.createdBy,
    required this.createdAt,
    required this.creator,
  });

  final int id;
  final String title;
  final String description;
  final DateTime? deadline;
  final bool isClosed;
  final int? createdBy;
  final DateTime? createdAt;
  final AppUser? creator;

  String? get creatorName {
    final name = creator?.name.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deadline: DateTime.tryParse(json['deadline'] as String? ?? ''),
      isClosed: json['is_closed'] as bool? ?? false,
      createdBy: json['created_by'] as int?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      creator: json['creator'] is Map<String, dynamic>
          ? AppUser.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
    );
  }
}
