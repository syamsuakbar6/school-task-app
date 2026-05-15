import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';

class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  late Future<List<Map<String, dynamic>>> _studentsFuture;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _studentsFuture = widget.session.api.adminListStudents();
  }

  void _refresh() => setState(_load);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddStudentDialog() async {
    final nisnController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Siswa Baru'),
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
                  controller: nisnController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'NISN',
                    hintText: '10 digit angka',
                    counterText: '',
                  ),
                  validator: (v) {
                    if ((v ?? '').length != 10) return 'NISN harus 10 digit';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  validator: (v) {
                    if ((v ?? '').trim().length < 3) {
                      return 'Nama minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Password default: NISN siswa',
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
                        await widget.session.api.adminCreateStudent(
                          nisn: nisnController.text.trim(),
                          name: nameController.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                        _refresh();
                        if (mounted) {
                          AppFeedback.success(
                            this.context,
                            'Siswa berhasil ditambahkan.',
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
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Siswa'),
        content: Text(
          'Hapus akun ${student['name']}? Siswa akan dikeluarkan dari semua kelas.',
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
      await widget.session.api.adminDeleteUser(student['id'] as int);
      _refresh();
      if (mounted) {
        AppFeedback.success(
          context,
          '${student['name']} berhasil dihapus.',
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
        title: const Text('Kelola Siswa'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tambah Siswa'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _studentsFuture,
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

          final students = (snapshot.data ?? [])
              .where((u) => u['role'] == 'student')
              .where((student) {
                final query = _query.trim().toLowerCase();
                if (query.isEmpty) return true;
                final name = (student['name'] as String? ?? '').toLowerCase();
                final nisn = (student['nisn'] as String? ?? '').toLowerCase();
                return name.contains(query) || nisn.contains(query);
              })
              .toList();

          if (students.isEmpty) {
            return Column(
              children: [
                _AdminSearchField(
                  controller: _searchController,
                  hintText: 'Cari nama atau NISN',
                  onChanged: (value) => setState(() => _query = value),
                ),
                Expanded(
                  child: EmptyState(
                    icon: Icons.people_outline,
                    title: _query.trim().isEmpty
                        ? 'Belum ada siswa'
                        : 'Siswa tidak ditemukan',
                    message: _query.trim().isEmpty
                        ? 'Ketuk tombol di bawah untuk menambah siswa baru.'
                        : 'Coba kata kunci lain.',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _AdminSearchField(
                controller: _searchController,
                hintText: 'Cari nama atau NISN',
                onChanged: (value) => setState(() => _query = value),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            _initials(student['name'] as String),
                            style: TextStyle(
                              color: colorScheme.primary,
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
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                          ),
                          onPressed: () => _deleteStudent(student),
                        ),
                      ),
                    );
                  },
                ),
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

class _AdminSearchField extends StatelessWidget {
  const _AdminSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Bersihkan pencarian',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
    );
  }
}
