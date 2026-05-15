import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/loading_state.dart';

class AdminAssignTeachersScreen extends StatefulWidget {
  const AdminAssignTeachersScreen({
    super.key,
    required this.session,
    required this.classData,
  });

  final AuthSession session;
  final Map<String, dynamic> classData;

  @override
  State<AdminAssignTeachersScreen> createState() =>
      _AdminAssignTeachersScreenState();
}

class _AdminAssignTeachersScreenState extends State<AdminAssignTeachersScreen> {
  late Future<List<Map<String, dynamic>>> _allTeachersFuture;
  Set<int> _assignedIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _allTeachersFuture = _loadTeachers();
  }

  Future<List<Map<String, dynamic>>> _loadTeachers() async {
    final classId = widget.classData['id'] as int;
    final teachers = await widget.session.api.adminListTeachers();
    final assignedTeachers =
        await widget.session.api.adminListClassTeachers(classId);
    _assignedIds =
        assignedTeachers.map((teacher) => teacher['id'] as int).toSet();
    return teachers;
  }

  Future<void> _toggleAssign(int teacherId, bool isAssigned) async {
    setState(() => _loading = true);
    try {
      final classId = widget.classData['id'] as int;
      if (isAssigned) {
        await widget.session.api.adminRemoveTeacherFromClass(
          classId: classId,
          teacherId: teacherId,
        );
        setState(() => _assignedIds.remove(teacherId));
        if (mounted) {
          AppFeedback.success(context, 'Guru dilepas dari kelas.');
        }
      } else {
        await widget.session.api.adminAssignTeacherToClass(
          classId: classId,
          teacherId: teacherId,
        );
        setState(() => _assignedIds.add(teacherId));
        if (mounted) {
          AppFeedback.success(context, 'Guru ditambahkan ke kelas.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Assign Guru'),
            Text(
              widget.classData['name'] as String,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _allTeachersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }

          final teachers = (snapshot.data ?? [])
              .where((user) => user['role'] == 'teacher')
              .toList();

          if (teachers.isEmpty) {
            return const Center(child: Text('Belum ada guru terdaftar'));
          }

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: teachers.length,
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  final id = teacher['id'] as int;
                  final isAssigned = _assignedIds.contains(id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAssigned
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainer,
                        child: Text(
                          _initials(teacher['name'] as String),
                          style: TextStyle(
                            color: isAssigned
                                ? colorScheme.secondary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        teacher['name'] as String,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text('NIP: ${teacher['nip'] ?? '-'}'),
                      trailing: Switch(
                        value: isAssigned,
                        onChanged: _loading
                            ? null
                            : (value) => _toggleAssign(id, isAssigned),
                      ),
                    ),
                  );
                },
              ),
              if (_loading)
                Container(
                  color: Colors.black.withValues(alpha: 0.1),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}
