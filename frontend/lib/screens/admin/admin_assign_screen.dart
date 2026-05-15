import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';

class AdminAssignScreen extends StatefulWidget {
  const AdminAssignScreen({
    super.key,
    required this.session,
    required this.classData,
  });

  final AuthSession session;
  final Map<String, dynamic> classData;

  @override
  State<AdminAssignScreen> createState() => _AdminAssignScreenState();
}

class _AdminAssignScreenState extends State<AdminAssignScreen> {
  late Future<List<Map<String, dynamic>>> _allStudentsFuture;
  Set<int> _assignedIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _allStudentsFuture = widget.session.api.adminListStudents();
    final students = widget.classData['students'] as List? ?? [];
    _assignedIds = students
        .map((s) => (s as Map<String, dynamic>)['id'] as int)
        .toSet();
  }

  Future<void> _toggleAssign(int studentId, bool isAssigned) async {
    setState(() => _loading = true);
    try {
      final classId = widget.classData['id'] as int;
      if (isAssigned) {
        await widget.session.api.adminRemoveStudentFromClass(
          classId: classId,
          studentId: studentId,
        );
        setState(() => _assignedIds.remove(studentId));
      } else {
        await widget.session.api.adminAssignStudentToClass(
          classId: classId,
          studentId: studentId,
        );
        setState(() => _assignedIds.add(studentId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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
            const Text('Assign Siswa'),
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
        future: _allStudentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }

          final students = (snapshot.data ?? [])
              .where((u) => u['role'] == 'student')
              .toList();

          if (students.isEmpty) {
            return const Center(child: Text('Belum ada siswa terdaftar'));
          }

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final id = student['id'] as int;
                  final isAssigned = _assignedIds.contains(id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAssigned
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainer,
                        child: Text(
                          _initials(student['name'] as String),
                          style: TextStyle(
                            color: isAssigned
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        student['name'] as String,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text('NISN: ${student['nisn'] ?? '-'}'),
                      trailing: Switch(
                        value: isAssigned,
                        onChanged: _loading
                            ? null
                            : (val) => _toggleAssign(id, isAssigned),
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
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
