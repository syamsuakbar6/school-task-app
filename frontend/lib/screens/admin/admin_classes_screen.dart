import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import 'admin_assign_screen.dart';
import 'admin_assign_teachers_screen.dart';
import '../../widgets/app_page_route.dart';

class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  late Future<List<Map<String, dynamic>>> _classesFuture;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _classesFuture = widget.session.api.adminListClasses(
      includeArchived: _showArchived,
    );
  }

  void _refresh() => setState(_load);

  Future<void> _showAddClassDialog() async {
    String gradeLevel = 'X';
    final majorController = TextEditingController();
    final sectionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Buat Kelas Baru'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ClassStructureFields(
                    gradeLevel: gradeLevel,
                    majorController: majorController,
                    sectionController: sectionController,
                    onGradeChanged: (value) {
                      setDialogState(() => gradeLevel = value ?? 'X');
                    },
                    onTextChanged: () => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _ClassPreview(
                    name: _generatedClassName(
                      gradeLevel: gradeLevel,
                      major: majorController.text,
                      section: sectionController.text,
                    ),
                    code: _generatedClassCode(
                      gradeLevel: gradeLevel,
                      major: majorController.text,
                      section: sectionController.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final name = _generatedClassName(
                          gradeLevel: gradeLevel,
                          major: majorController.text,
                          section: sectionController.text,
                        );
                        await widget.session.api.adminCreateClass(
                          name: name,
                          code: _generatedClassCode(
                            gradeLevel: gradeLevel,
                            major: majorController.text,
                            section: sectionController.text,
                          ),
                          gradeLevel: gradeLevel,
                          major: majorController.text.trim().toUpperCase(),
                          section: sectionController.text.trim().toUpperCase(),
                        );
                        if (context.mounted) Navigator.pop(context);
                        _refresh();
                        if (mounted) {
                          AppFeedback.success(
                            this.context,
                            'Kelas berhasil dibuat.',
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          error = e.toString();
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Buat'),
            ),
          ],
        ),
      ),
    );

    majorController.dispose();
    sectionController.dispose();
  }

  Future<void> _renameClass(Map<String, dynamic> cls) async {
    final parts = _classPartsFromData(cls);
    String gradeLevel = parts.gradeLevel;
    final majorController = TextEditingController(text: parts.major);
    final sectionController = TextEditingController(text: parts.section);
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ubah Kelas'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ClassStructureFields(
                    gradeLevel: gradeLevel,
                    majorController: majorController,
                    sectionController: sectionController,
                    onGradeChanged: (value) {
                      setDialogState(() => gradeLevel = value ?? 'X');
                    },
                    onTextChanged: () => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _ClassPreview(
                    name: _generatedClassName(
                      gradeLevel: gradeLevel,
                      major: majorController.text,
                      section: sectionController.text,
                    ),
                    code: _generatedClassCode(
                      gradeLevel: gradeLevel,
                      major: majorController.text,
                      section: sectionController.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final name = _generatedClassName(
                          gradeLevel: gradeLevel,
                          major: majorController.text,
                          section: sectionController.text,
                        );
                        await widget.session.api.adminUpdateClass(
                          classId: cls['id'] as int,
                          name: name,
                          code: _generatedClassCode(
                            gradeLevel: gradeLevel,
                            major: majorController.text,
                            section: sectionController.text,
                          ),
                          gradeLevel: gradeLevel,
                          major: majorController.text.trim().toUpperCase(),
                          section: sectionController.text.trim().toUpperCase(),
                        );
                        if (context.mounted) Navigator.pop(context);
                        _refresh();
                        if (mounted) {
                          AppFeedback.success(
                            this.context,
                            'Kelas berhasil diperbarui.',
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          error = e.toString();
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    majorController.dispose();
    sectionController.dispose();
  }

  Future<void> _archiveClass(Map<String, dynamic> cls) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arsipkan Kelas'),
        content: Text(
          'Arsipkan kelas ${cls['name']}? Kelas tidak muncul lagi untuk guru dan siswa, tetapi tugas dan pengumpulan tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.session.api.adminArchiveClass(cls['id'] as int);
      _refresh();
      if (mounted) {
        AppFeedback.success(context, '${cls['name']} diarsipkan.');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _unarchiveClass(Map<String, dynamic> cls) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulihkan Kelas'),
        content: Text(
          'Pulihkan kelas ${cls['name']} agar bisa dipakai lagi oleh guru dan siswa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('Pulihkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.session.api.adminUnarchiveClass(cls['id'] as int);
      _refresh();
      if (mounted) {
        AppFeedback.success(context, '${cls['name']} dipulihkan.');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _deleteClass(Map<String, dynamic> cls) async {
    final taskCount = cls['task_count'] as int? ?? 0;
    final submissionCount = cls['submission_count'] as int? ?? 0;
    if (taskCount > 0 || submissionCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kelas tidak bisa dihapus'),
          content: Text(
            'Kelas ${cls['name']} masih memiliki $taskCount tugas dan '
            '$submissionCount pengumpulan. Data akademik ini perlu tetap aman.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelas'),
        content: Text(
          'Hapus kelas ${cls['name']}? Kelas kosong ini akan dihapus dan relasi siswa/guru di kelas ini akan dilepas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.session.api.adminDeleteClass(cls['id'] as int);
      _refresh();
      if (mounted) {
        AppFeedback.success(
          context,
          '${cls['name']} berhasil dihapus.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kelas'),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _refresh();
            },
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            label: Text(_showArchived ? 'Semua kelas' : 'Kelas aktif'),
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClassDialog,
        icon: const Icon(Icons.add),
        label: const Text('Buat Kelas'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _classesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final classes = snapshot.data ?? [];

          if (classes.isEmpty) {
            return const EmptyState(
              icon: Icons.class_outlined,
              title: 'Belum ada kelas',
              message: 'Ketuk tombol di bawah untuk membuat kelas baru.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final cls = classes[index];
              final students = cls['students'] as List? ?? [];
              final teachers = cls['teachers'] as List? ?? [];
              final taskCount = cls['task_count'] as int? ?? 0;
              final submissionCount = cls['submission_count'] as int? ?? 0;
              final isArchived = cls['is_archived'] as bool? ?? false;
              final canDelete = taskCount == 0 && submissionCount == 0;
              return Card(
                color: isArchived
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : null,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.class_outlined,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cls['name'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (isArchived) ...[
                              const _ArchivedChip(),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              'Kode: ${cls['code'] ?? '-'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tahun ajaran: ${cls['academic_year_name'] ?? '-'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _CountChip(
                                  icon: Icons.people_outline,
                                  label: '${students.length} siswa',
                                ),
                                _CountChip(
                                  icon: Icons.school_outlined,
                                  label: '${teachers.length} guru',
                                ),
                                _CountChip(
                                  icon: Icons.assignment_outlined,
                                  label: '$taskCount tugas',
                                ),
                                _CountChip(
                                  icon: Icons.upload_file_outlined,
                                  label: '$submissionCount pengumpulan',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              teachers.isEmpty
                                  ? 'Guru: belum ditugaskan'
                                  : 'Guru: ${_names(teachers)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.person_add_outlined,
                                    color: colorScheme.primary,
                                    size: 18,
                                  ),
                                  label: const Text('Siswa'),
                                  onPressed: isArchived
                                      ? null
                                      : () => Navigator.of(context)
                                          .push(
                                            appPageRoute(AdminAssignScreen(
                                              session: widget.session,
                                              classData: cls,
                                            )),
                                          )
                                          .then((_) => _refresh()),
                                ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.school_outlined,
                                    color: colorScheme.secondary,
                                    size: 18,
                                  ),
                                  label: const Text('Guru'),
                                  onPressed: isArchived
                                      ? null
                                      : () => Navigator.of(context)
                                          .push(
                                            appPageRoute(
                                                AdminAssignTeachersScreen(
                                              session: widget.session,
                                              classData: cls,
                                            )),
                                          )
                                          .then((_) => _refresh()),
                                ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: isArchived
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.primary,
                                    size: 18,
                                  ),
                                  label: const Text('Ubah'),
                                  onPressed: isArchived
                                      ? null
                                      : () => _renameClass(cls),
                                ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    isArchived
                                        ? Icons.unarchive_outlined
                                        : Icons.archive_outlined,
                                    color: colorScheme.secondary,
                                    size: 18,
                                  ),
                                  label: Text(
                                      isArchived ? 'Pulihkan' : 'Arsipkan'),
                                  onPressed: () => isArchived
                                      ? _unarchiveClass(cls)
                                      : _archiveClass(cls),
                                ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    canDelete
                                        ? Icons.delete_outline
                                        : Icons.lock_outline,
                                    color: canDelete
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                    size: 18,
                                  ),
                                  label: Text(canDelete ? 'Hapus' : 'Terkunci'),
                                  onPressed: () => _deleteClass(cls),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _names(List<dynamic> users) {
    final names = users
        .map((user) => user is Map ? user['name'] as String? : null)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();
    if (names.isEmpty) return '-';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} +${names.length - 3} lainnya';
  }

  String _generatedClassName({
    required String gradeLevel,
    required String major,
    required String section,
  }) {
    final normalizedMajor = _normalizePart(major);
    final normalizedSection = _normalizePart(section);
    return [gradeLevel, normalizedMajor, normalizedSection]
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  String _generatedClassCode({
    required String gradeLevel,
    required String major,
    required String section,
  }) {
    final name = _generatedClassName(
      gradeLevel: gradeLevel,
      major: major,
      section: section,
    );
    return name.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _normalizePart(String value) {
    return value.trim().toUpperCase().split(RegExp(r'\s+')).join(' ');
  }

  _ClassParts _classPartsFromData(Map<String, dynamic> cls) {
    final gradeLevel = (cls['grade_level'] as String?)?.trim().toUpperCase();
    final major = (cls['major'] as String?)?.trim().toUpperCase();
    final section = (cls['section'] as String?)?.trim().toUpperCase();
    if (gradeLevel != null &&
        (gradeLevel == 'X' || gradeLevel == 'XI' || gradeLevel == 'XII') &&
        gradeLevel.isNotEmpty &&
        major != null &&
        major.isNotEmpty &&
        section != null &&
        section.isNotEmpty) {
      return _ClassParts(
        gradeLevel: gradeLevel,
        major: major,
        section: section,
      );
    }
    return _parseClassName(cls['name'] as String? ?? '');
  }

  _ClassParts _parseClassName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final gradeLevel = parts.first.toUpperCase();
      if (gradeLevel == 'X' || gradeLevel == 'XI' || gradeLevel == 'XII') {
        return _ClassParts(
          gradeLevel: gradeLevel,
          major: parts.sublist(1, parts.length - 1).join(' ').toUpperCase(),
          section: parts.last.toUpperCase(),
        );
      }
    }
    return const _ClassParts(gradeLevel: 'X', major: '', section: '');
  }
}

class _ClassParts {
  const _ClassParts({
    required this.gradeLevel,
    required this.major,
    required this.section,
  });

  final String gradeLevel;
  final String major;
  final String section;
}

class _ClassStructureFields extends StatelessWidget {
  const _ClassStructureFields({
    required this.gradeLevel,
    required this.majorController,
    required this.sectionController,
    required this.onGradeChanged,
    required this.onTextChanged,
  });

  final String gradeLevel;
  final TextEditingController majorController;
  final TextEditingController sectionController;
  final ValueChanged<String?> onGradeChanged;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          value: gradeLevel,
          decoration: const InputDecoration(labelText: 'Tingkat'),
          items: const [
            DropdownMenuItem(value: 'X', child: Text('X')),
            DropdownMenuItem(value: 'XI', child: Text('XI')),
            DropdownMenuItem(value: 'XII', child: Text('XII')),
          ],
          onChanged: onGradeChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: majorController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Jurusan',
            hintText: 'contoh: RPL',
          ),
          onChanged: (_) => onTextChanged(),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Jurusan wajib diisi';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: sectionController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Nomor Kelas',
            hintText: 'contoh: 1',
          ),
          onChanged: (_) => onTextChanged(),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Nomor kelas wajib diisi';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _ClassPreview extends StatelessWidget {
  const _ClassPreview({
    required this.name,
    required this.code,
  });

  final String name;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = name.trim().isEmpty ? '-' : name;
    final displayCode = code.trim().isEmpty ? '-' : code;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Preview',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayName,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Kode: $displayCode',
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

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedChip extends StatelessWidget {
  const _ArchivedChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                'Diarsipkan',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
