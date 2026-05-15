import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _usersFuture = widget.session.api.adminListUsers();
  }

  void _refresh() => setState(_load);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _roleColor(String role, ColorScheme colorScheme) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'teacher':
        return Colors.orange;
      default:
        return colorScheme.primary;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'teacher':
        return 'Guru';
      default:
        return 'Siswa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semua Pengguna'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
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

          final users = (snapshot.data ?? []).where((user) {
            final query = _query.trim().toLowerCase();
            if (query.isEmpty) return true;
            final name = (user['name'] as String? ?? '').toLowerCase();
            final role = (user['role'] as String? ?? '').toLowerCase();
            final nisn = (user['nisn'] as String? ?? '').toLowerCase();
            final nip = (user['nip'] as String? ?? '').toLowerCase();
            return name.contains(query) ||
                role.contains(query) ||
                nisn.contains(query) ||
                nip.contains(query);
          }).toList();

          if (users.isEmpty) {
            return Column(
              children: [
                _AdminSearchField(
                  controller: _searchController,
                  hintText: 'Cari nama, role, NISN, atau NIP',
                  onChanged: (value) => setState(() => _query = value),
                ),
                Expanded(
                  child: EmptyState(
                    icon: Icons.people_outline,
                    title: _query.trim().isEmpty
                        ? 'Belum ada pengguna'
                        : 'Pengguna tidak ditemukan',
                    message:
                        _query.trim().isEmpty ? '' : 'Coba kata kunci lain.',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _AdminSearchField(
                controller: _searchController,
                hintText: 'Cari nama, role, NISN, atau NIP',
                onChanged: (value) => setState(() => _query = value),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final role = user['role'] as String? ?? 'student';
                    final roleColor = _roleColor(role, colorScheme);
                    final identifier = role == 'student'
                        ? 'NISN: ${user['nisn'] ?? '-'}'
                        : 'NIP: ${user['nip'] ?? '-'}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: roleColor.withValues(alpha: 0.15),
                          child: Text(
                            _initials(user['name'] as String? ?? '?'),
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          user['name'] as String? ?? '-',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(identifier),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _roleLabel(role),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: roleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
