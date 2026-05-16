import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/loading_state.dart';

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
      if (mounted) {
        AppFeedback.success(context, 'Siswa berhasil ditambahkan.');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importExcel() async {
    final shouldPick = await _showImportGuideDialog();
    if (shouldPick != true) return;

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
        await _showImportResultDialog(
          assignedCount: assignedCount,
          createdCount: createdCount,
          skippedCount: skippedCount,
          skipped: skipped,
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
        AppFeedback.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showImportGuideDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Siswa dari Excel'),
        content: const SingleChildScrollView(
          child: _ImportGuideContent(compact: false),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Pilih File'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportResultDialog({
    required int assignedCount,
    required int createdCount,
    required int skippedCount,
    required List<dynamic> skipped,
  }) {
    return showDialog<void>(
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
                Text(
                  'Baris yang dilewati',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: skipped.length,
                    itemBuilder: (context, index) {
                      final item = skipped[index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SkippedRowTile(item: item),
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
            return const LoadingList();
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Column(
                      children: [
                        const _ImportGuideCard(),
                        const SizedBox(height: 10),
                        TextField(
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
                      ],
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
                                onPressed:
                                    _loading ? null : () => _assignStudent(id),
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

class _ImportGuideCard extends StatelessWidget {
  const _ImportGuideCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Format Excel Import'),
            content: const SingleChildScrollView(
              child: _ImportGuideContent(compact: false),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(child: _ImportGuideContent(compact: true)),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportGuideContent extends StatelessWidget {
  const _ImportGuideContent({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Format Excel: kolom NISN dan Nama',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Baris pertama wajib header. Ketuk untuk melihat panduan.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gunakan file .xlsx atau .xlsm dengan baris pertama sebagai header.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        const _ExampleTable(),
        const SizedBox(height: 12),
        Text(
          'Kolom wajib: NISN. Kolom Nama disarankan agar akun siswa baru bisa dibuat otomatis.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'NISN harus 10 digit angka. Password default untuk akun baru adalah NISN siswa.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Baris yang NISN-nya duplikat, tidak valid, atau sudah terdaftar di kelas lain akan dilewati dan ditampilkan setelah import.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ExampleTable extends StatelessWidget {
  const _ExampleTable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final border = BorderSide(color: colorScheme.outlineVariant);

    Widget cell(String text, {bool header = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: header ? colorScheme.surfaceContainerHighest : null,
            border: Border(right: border, bottom: border),
          ),
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: header ? null : 'monospace',
              fontWeight: header ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              cell('NISN', header: true),
              cell('Nama', header: true)
            ]),
            Row(children: [cell('0012345678'), cell('Siti Aminah')]),
            Row(children: [cell('0012345679'), cell('Budi Santoso')]),
          ],
        ),
      ),
    );
  }
}

class _SkippedRowTile extends StatelessWidget {
  const _SkippedRowTile({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Baris ${item['row'] ?? '-'} - NISN ${item['nisn'] ?? '-'}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item['reason'] as String? ?? 'Baris dilewati.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
