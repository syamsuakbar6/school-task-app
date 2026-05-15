import 'package:file_picker/file_picker.dart';
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
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  void _load() {
    _allStudentsFuture = _loadUnassignedStudents();
  }

  Future<List<Map<String, dynamic>>> _loadUnassignedStudents() async {
    final students = await widget.session.api.adminListStudents();
    final classes = await widget.session.api.adminListClasses();
    final assignedIds = <int>{};

    for (final classData in classes) {
      final classStudents = classData['students'] as List? ?? [];
      for (final student in classStudents) {
        if (student is Map<String, dynamic>) {
          assignedIds.add(student['id'] as int);
        }
      }
    }

    _assignedIds = assignedIds;
    return students;
  }

  Future<void> _assignStudent(int studentId) async {
    setState(() => _loading = true);
    try {
      final classId = widget.classData['id'] as int;
      await widget.session.api.adminAssignStudentToClass(
        classId: classId,
        studentId: studentId,
      );
      setState(() => _assignedIds.add(studentId));
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

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;

    setState(() => _loading = true);
    try {
      final classId = widget.classData['id'] as int;
      final response = await widget.session.api.adminImportStudentsToClass(
        classId: classId,
        file: file,
      );
      final assignedCount = response['assigned_count'] as int? ?? 0;
      final createdCount = response['created_count'] as int? ?? 0;
      final skippedCount = response['skipped_count'] as int? ?? 0;
      final skipped = response['skipped'] as List? ?? [];

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Excel Selesai'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$assignedCount siswa berhasil ditambahkan.'),
                  if (createdCount > 0)
                    Text('$createdCount akun siswa baru dibuat.'),
                  Text('$skippedCount baris dilewati.'),
                  if (skipped.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Catatan:'),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: skipped.length > 5 ? 5 : skipped.length,
                        itemBuilder: (context, index) {
                          final item = skipped[index] as Map<String, dynamic>;
                          return Text(
                            'Baris ${item['row']}: ${item['nisn']} - ${item['reason']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      if (mounted) {
        setState(() {
          _searchController.clear();
          _load();
        });
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        actions: [
          IconButton(
            tooltip: 'Import Excel',
            onPressed: _loading ? null : _importExcel,
            icon: const Icon(Icons.upload_file_outlined),
          ),
        ],
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

          final query = _searchController.text.trim().toLowerCase();
          final students = (snapshot.data ?? []).where((student) {
            if (student['role'] != 'student') return false;
            final id = student['id'] as int;
            if (_assignedIds.contains(id)) return false;
            if (query.isEmpty) return true;
            final name = (student['name'] as String? ?? '').toLowerCase();
            final nisn = (student['nisn'] as String? ?? '').toLowerCase();
            return name.contains(query) || nisn.contains(query);
          }).toList();

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau NISN',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                icon: const Icon(Icons.close),
                                onPressed: _searchController.clear,
                              ),
                      ),
                    ),
                  ),
                  if (students.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Tidak ada siswa yang bisa ditambahkan'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final id = student['id'] as int;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.surfaceContainer,
                                child: Text(
                                  _initials(student['name'] as String),
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
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
                              trailing: IconButton.filled(
                                tooltip: 'Tambahkan ke kelas',
                                icon: const Icon(Icons.add),
                                onPressed: _loading
                                    ? null
                                    : () => _assignStudent(id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
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
