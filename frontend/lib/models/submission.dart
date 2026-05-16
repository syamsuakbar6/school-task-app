import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'task.dart';

class Submission {
  const Submission({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.grade,
    required this.submittedAt,
    required this.hasFile,
    required this.fileName,
    required this.downloadUrl,
    required this.status,
    required this.version,
    required this.gradedBy,
    required this.gradedAt,
    required this.feedback,
    required this.task,
    required this.user,
  });

  final int id;
  final int taskId;
  final int userId;
  final int? grade;
  final DateTime submittedAt;
  final bool hasFile;
  final String? fileName;
  final String? downloadUrl;
  final String? status;
  final int? version;
  final AppUser? gradedBy;
  final DateTime? gradedAt;
  final String? feedback;
  final Task task;
  final AppUser user;

  String get statusLabel {
    if (grade != null) return 'Dinilai: $grade';
    final normalized = status?.trim();
    if (normalized == null || normalized.isEmpty) return 'Terkumpul';
    switch (normalized.toLowerCase()) {
      case 'submitted':
        return 'Terkumpul';
      case 'graded':
        return 'Dinilai';
      default:
        return normalized[0].toUpperCase() + normalized.substring(1);
    }
  }

  bool get isImageFile {
    final lowerName = fileName?.toLowerCase() ?? '';
    return lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg');
  }

  factory Submission.fromJson(Map<String, dynamic> json) {
    debugPrint('PARSING SUBMISSION: id=${json['id']} '
        'task_id=${json['task_id']} '
        'user_id=${json['user_id']} '
        'file_name=${json['file_name']} '
        'download_url=${json['download_url']} '
        'status=${json['status']} '
        'has_task=${json['task'] != null} '
        'has_user=${json['user'] != null}');

    return Submission(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      userId: json['user_id'] as int,
      grade: json['grade'] as int?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      hasFile: json['has_file'] as bool? ?? false,
      fileName: json['file_name'] as String?,
      downloadUrl: json['download_url'] as String?,
      status: json['status'] as String?,
      version: json['version'] as int?,
      gradedBy: json['graded_by'] is Map<String, dynamic>
          ? AppUser.fromJson(json['graded_by'] as Map<String, dynamic>)
          : null,
      gradedAt: DateTime.tryParse(json['graded_at'] as String? ?? ''),
      feedback: json['feedback'] as String?,
      task: Task.fromJson(json['task'] as Map<String, dynamic>),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
