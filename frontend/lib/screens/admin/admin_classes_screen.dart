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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _classesFuture = widget.session.api.adminListClasses();
  }

  void _refresh() => setState(_load);

  Future<void> _showAddClassDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
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
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kelas',
                    hintText: 'contoh: X RPL 1',
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().length < 3) {
                      return 'Nama kelas minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Kelas',
                    hintText: 'contoh: XRPL1',
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return 'Kode kelas wajib diisi';
                    return null;
                  },
                ),
              ],
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
                        await widget.session.api.adminCreateClass(
                          name: nameController.text.trim(),
                          code: codeController.text.trim(),
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
  }

  Future<void> _deleteClass(Map<String, dynamic> cls) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelas'),
        content: Text(
          'Hapus kelas ${cls['name']}? Semua siswa akan dikeluarkan dari kelas ini.',
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
              return Card(
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
                            Text(
                              'Kode: ${cls['code'] ?? '-'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
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
                                  onPressed: () => Navigator.of(context).push(
                                    appPageRoute(AdminAssignScreen(
                                      session: widget.session,
                                      classData: cls,
                                    )),
                                  ).then((_) => _refresh()),
                                ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.school_outlined,
                                    color: colorScheme.secondary,
                                    size: 18,
                                  ),
                                  label: const Text('Guru'),
                                  onPressed: () => Navigator.of(context).push(
                                    appPageRoute(AdminAssignTeachersScreen(
                                      session: widget.session,
                                      classData: cls,
                                    )),
                                  ).then((_) => _refresh()),
                                ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colorScheme.error,
                                    size: 18,
                                  ),
                                  label: const Text('Hapus'),
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
