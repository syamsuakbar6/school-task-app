import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/empty_state.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  late Future<List<Map<String, dynamic>>> _teachersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _teachersFuture = widget.session.api.adminListTeachers();
  }

  void _refresh() => setState(_load);

  Future<void> _showAddTeacherDialog() async {
    final nipController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Guru Baru'),
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
                  controller: nipController,
                  keyboardType: TextInputType.number,
                  maxLength: 18,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'NIP',
                    hintText: '18 digit angka',
                    counterText: '',
                  ),
                  validator: (value) {
                    if ((value ?? '').length != 18) {
                      return 'NIP harus 18 digit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  validator: (value) {
                    if ((value ?? '').trim().length < 3) {
                      return 'Nama minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Password default: NIP guru',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                        await widget.session.api.adminCreateTeacher(
                          nip: nipController.text.trim(),
                          name: nameController.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                        _refresh();
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
  }

  Future<void> _deleteTeacher(Map<String, dynamic> teacher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Guru'),
        content: Text(
          'Hapus akun ${teacher['name']}? Guru akan dilepas dari semua kelas.',
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
      await widget.session.api.adminDeleteUser(teacher['id'] as int);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${teacher['name']} berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Guru'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherDialog,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Tambah Guru'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _teachersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final teachers = (snapshot.data ?? [])
              .where((user) => user['role'] == 'teacher')
              .toList();

          if (teachers.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              title: 'Belum ada guru',
              message: 'Tap tombol di bawah untuk menambah guru baru.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Text(
                      _initials(teacher['name'] as String),
                      style: TextStyle(
                        color: colorScheme.secondary,
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
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    onPressed: () => _deleteTeacher(teacher),
                  ),
                ),
              );
            },
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
