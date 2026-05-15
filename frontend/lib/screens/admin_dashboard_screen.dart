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

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.session});

  final AuthSession session;

  Future<void> _logout(BuildContext context) async {
    await session.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      appPageRoute(LoginScreen(session: session)),
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
          appPageRoute(AdminStudentsScreen(session: session)),
        ),
      ),
      _AdminMenu(
        icon: Icons.class_outlined,
        label: 'Kelola Kelas',
        description: 'Buat kelas, assign siswa dan guru',
        color: Colors.green,
        onTap: () => Navigator.of(context).push(
          appPageRoute(AdminClassesScreen(session: session)),
        ),
      ),
      _AdminMenu(
        icon: Icons.school_outlined,
        label: 'Kelola Guru',
        description: 'Tambah, lihat, dan hapus akun guru',
        color: Colors.teal,
        onTap: () => Navigator.of(context).push(
          appPageRoute(AdminTeachersScreen(session: session)),
        ),
      ),
      _AdminMenu(
        icon: Icons.manage_accounts_outlined,
        label: 'Semua Pengguna',
        description: 'Lihat daftar semua user di sistem',
        color: Colors.orange,
        onTap: () => Navigator.of(context).push(
          appPageRoute(AdminUsersScreen(session: session)),
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
              'Admin Panel',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            Text(
              'Halo, ${session.user?.name ?? 'Admin'}',
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
              appPageRoute(ChangePasswordScreen(session: session)),
            ),
            icon: const Icon(Icons.lock_reset_outlined),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              color: colorScheme.primary,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      Color.lerp(colorScheme.primary, Colors.black, 0.2)!,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panel Administrator',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola data siswa, kelas, dan pengguna sistem',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Menu',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Grid menu
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: menus
                  .map((menu) => _AdminMenuCard(menu: menu))
                  .toList(),
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
                  borderRadius: BorderRadius.circular(12),
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
