import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../theme/theme_mode_scope.dart';
import '../widgets/app_page_route.dart';
import 'admin/admin_classes_screen.dart';
import 'admin/admin_students_screen.dart';
import 'admin/admin_teachers_screen.dart';
import 'admin/admin_users_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<_AdminMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _loadMetrics();
  }

  Future<_AdminMetrics> _loadMetrics() async {
    final users = await widget.session.api.adminListUsers();
    final classes = await widget.session.api.adminListClasses();
    return _AdminMetrics(
      students: users.where((user) => user['role'] == 'student').length,
      teachers: users.where((user) => user['role'] == 'teacher').length,
      classes: classes.length,
      users: users.length,
    );
  }

  void _refreshMetrics() {
    setState(() {
      _metricsFuture = _loadMetrics();
    });
  }

  Future<void> _logout(BuildContext context) async {
    await widget.session.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      appPageRoute(LoginScreen(session: widget.session)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final themeModeController = ThemeModeScope.of(context);

    final menus = [
      _AdminMenu(
        icon: Icons.people_outline,
        label: 'Kelola Siswa',
        description: 'Tambah, lihat, dan hapus akun siswa',
        color: Colors.blue,
        onTap: () => Navigator.of(context).push(
          appPageRoute(AdminStudentsScreen(session: widget.session)),
        ),
      ),
      _AdminMenu(
        icon: Icons.class_outlined,
        label: 'Kelola Kelas',
        description: 'Buat kelas, atur siswa dan guru',
        color: Colors.green,
        onTap: () => Navigator.of(context).push(
          appPageRoute(AdminClassesScreen(session: widget.session)),
        ),
      ),
      _AdminMenu(
        icon: Icons.school_outlined,
        label: 'Kelola Guru',
        description: 'Tambah, lihat, dan hapus akun guru',
        color: Colors.teal,
        onTap: () => Navigator.of(context).push(
          appPageRoute(AdminTeachersScreen(session: widget.session)),
        ),
      ),
      _AdminMenu(
        icon: Icons.manage_accounts_outlined,
        label: 'Semua Pengguna',
        description: 'Lihat daftar semua pengguna di sistem',
        color: Colors.orange,
        onTap: () => Navigator.of(context).push(
          appPageRoute(AdminUsersScreen(session: widget.session)),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Panel Admin',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            Text(
              'Halo, ${widget.session.user?.name ?? 'Admin'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Mode terang' : 'Mode gelap',
            onPressed: () =>
                themeModeController.toggleFromBrightness(theme.brightness),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Ganti password',
            onPressed: () => Navigator.of(context).push(
              appPageRoute(ChangePasswordScreen(session: widget.session)),
            ),
            icon: const Icon(Icons.lock_reset_outlined),
          ),
          IconButton(
            tooltip: 'Muat ulang data',
            onPressed: _refreshMetrics,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 560 ? 3 : 2;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: colorScheme.primary,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          Color.lerp(colorScheme.primary, Colors.black, 0.18)!,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panel Administrator',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kelola siswa, guru, kelas, dan akun pengguna',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FutureBuilder<_AdminMetrics>(
                  future: _metricsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _MetricsLoadingGrid();
                    }
                    if (snapshot.hasError) {
                      return _MetricsErrorCard(onRetry: _refreshMetrics);
                    }
                    final metrics = snapshot.requireData;
                    return _MetricsGrid(metrics: metrics);
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  'Menu',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  itemCount: menus.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.08,
                  ),
                  itemBuilder: (context, index) {
                    return _AdminMenuCard(menu: menus[index]);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminMetrics {
  const _AdminMetrics({
    required this.students,
    required this.teachers,
    required this.classes,
    required this.users,
  });

  final int students;
  final int teachers;
  final int classes;
  final int users;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final _AdminMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 560 ? 4 : 2;
        final items = [
          _MetricItem(
            icon: Icons.people_outline,
            label: 'Siswa',
            value: metrics.students,
            color: Colors.blue,
          ),
          _MetricItem(
            icon: Icons.school_outlined,
            label: 'Guru',
            value: metrics.teachers,
            color: Colors.teal,
          ),
          _MetricItem(
            icon: Icons.class_outlined,
            label: 'Kelas',
            value: metrics.classes,
            color: Colors.green,
          ),
          _MetricItem(
            icon: Icons.manage_accounts_outlined,
            label: 'Pengguna',
            value: metrics.users,
            color: Colors.orange,
          ),
        ];

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.72,
          ),
          itemBuilder: (context, index) => _MetricCard(item: items[index]),
        );
      },
    );
  }
}

class _MetricsLoadingGrid extends StatelessWidget {
  const _MetricsLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 560 ? 4 : 2;
        return GridView.builder(
          itemCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.72,
          ),
          itemBuilder: (context, index) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 64,
                      height: 18,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 42,
                      height: 12,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetricsErrorCard extends StatelessWidget {
  const _MetricsErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Ringkasan data belum bisa dimuat.'),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const Spacer(),
            Text(
              item.value.toString(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenu {
  const _AdminMenu({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({required this.menu});

  final _AdminMenu menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: menu.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: menu.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(menu.icon, color: menu.color, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menu.label,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    menu.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
