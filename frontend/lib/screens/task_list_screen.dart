import 'package:flutter/material.dart';

import '../models/submission.dart';
import '../models/task.dart';
import '../services/auth_session.dart';
import '../theme/theme_mode_scope.dart';
import '../widgets/app_page_route.dart';
import '../widgets/app_error_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_list_tile.dart';
import 'create_task_screen.dart';
import 'login_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Task>> _tasksFuture;
  Future<List<Submission>>? _studentSubmissionsFuture;

  // State untuk multi-class (teacher only)
  List<Map<String, dynamic>> _classes = [];
  int? _selectedClassId;
  bool _classesLoaded = false;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  /// Pertama kali masuk: kalau teacher, fetch kelas dulu baru fetch task.
  Future<void> _initLoad() async {
    if (widget.session.user?.isTeacher == true) {
      await _loadClasses();
    } else {
      _load();
    }
  }

  /// Fetch daftar kelas yang bisa diakses teacher.
  Future<void> _loadClasses() async {
    try {
      final classes = await widget.session.api.fetchClasses();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _classesLoaded = true;
        // Auto-pilih kelas pertama kalau belum ada pilihan
        if (_selectedClassId == null && classes.isNotEmpty) {
          _selectedClassId = classes.first['id'] as int;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _classesLoaded = true);
    }
    _load();
  }

  void _load() {
    setState(() {
      _tasksFuture = widget.session.api.fetchTasks(
        classId: _selectedClassId,
      );
      _studentSubmissionsFuture = widget.session.user?.isStudent == true
          ? widget.session.api.fetchSubmissions()
          : null;
    });
  }

  void _refresh() {
    if (widget.session.user?.isTeacher == true) {
      _loadClasses();
    } else {
      _load();
    }
  }

  Future<void> _reloadTasks() async {
    final nextTasks = widget.session.api.fetchTasks(
      classId: _selectedClassId,
    );
    final nextSubmissions = widget.session.user?.isStudent == true
        ? widget.session.api.fetchSubmissions()
        : null;
    setState(() {
      _tasksFuture = nextTasks;
      _studentSubmissionsFuture = nextSubmissions;
    });
    await nextTasks;
    if (nextSubmissions != null) {
      await nextSubmissions;
    }
  }

  Future<void> _logout() async {
    await widget.session.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      appPageRoute(LoginScreen(session: widget.session)),
      (_) => false,
    );
  }

  Future<void> _openCreateTask() async {
    final created = await Navigator.of(context).push<bool>(
      appPageRoute(CreateTaskScreen(session: widget.session)),
    );
    if (created == true) {
      await _reloadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeModeController = ThemeModeScope.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = widget.session.user;
    final isTeacher = user?.isTeacher == true;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Tasks',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            // Teacher: tampilkan dropdown kelas
            // Student: tampilkan sapaan biasa
            if (isTeacher && _classes.isNotEmpty)
              _ClassDropdown(
                classes: _classes,
                selectedClassId: _selectedClassId,
                onChanged: (classId) {
                  setState(() => _selectedClassId = classId);
                  _load();
                },
              )
            else if (isTeacher && !_classesLoaded)
              Text(
                'Memuat kelas...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else if (isTeacher && _classesLoaded && _classes.isEmpty)
              Text(
                'Tidak ada kelas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                'Hello, ${user?.name ?? 'Student'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              themeModeController.toggleFromBrightness(theme.brightness);
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                key: ValueKey<bool>(isDark),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: _openCreateTask,
              icon: const Icon(Icons.add),
              label: const Text('Task'),
            )
          : null,
      body: FutureBuilder<List<Task>>(
        future: _tasksFuture,
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

          final tasks = snapshot.data ?? [];
          final activeCount = tasks.where((task) => !task.isClosed).length;

          if (user?.isStudent == true && _studentSubmissionsFuture != null) {
            return FutureBuilder<List<Submission>>(
              future: _studentSubmissionsFuture,
              builder: (context, submissionsSnapshot) {
                final submissions = submissionsSnapshot.data ?? [];
                return _TaskListBody(
                  tasks: tasks,
                  activeCount: activeCount,
                  showSubmissionStatus: true,
                  submissionsByTaskId: _latestSubmissionByTaskId(submissions),
                  onRefresh: _reloadTasks,
                  onOpenTask: _openTaskDetail,
                );
              },
            );
          }

          return _TaskListBody(
            tasks: tasks,
            activeCount: activeCount,
            showSubmissionStatus: false,
            submissionsByTaskId: const {},
            onRefresh: _reloadTasks,
            onOpenTask: _openTaskDetail,
          );
        },
      ),
    );
  }

  Map<int, Submission> _latestSubmissionByTaskId(List<Submission> submissions) {
    final byTaskId = <int, Submission>{};
    for (final submission in submissions) {
      final current = byTaskId[submission.taskId];
      if (current == null ||
          submission.submittedAt.isAfter(current.submittedAt)) {
        byTaskId[submission.taskId] = submission;
      }
    }
    return byTaskId;
  }

  Future<void> _openTaskDetail(Task task) async {
    await Navigator.of(context).push(
      appPageRoute(
        TaskDetailScreen(
          session: widget.session,
          taskId: task.id,
        ),
      ),
    );
    await _reloadTasks();
  }
}

// ── Dropdown Kelas (Teacher Only) ─────────────────────────────────────────────

class _ClassDropdown extends StatelessWidget {
  const _ClassDropdown({
    required this.classes,
    required this.selectedClassId,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> classes;
  final int? selectedClassId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: selectedClassId,
        isDense: true,
        icon: Icon(
          Icons.arrow_drop_down,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
        dropdownColor: Theme.of(context).cardColor,
        items: classes.map((c) {
          return DropdownMenuItem<int>(
            value: c['id'] as int,
            child: Text(
              c['name'] as String? ?? 'Kelas ${c['id']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

// ── Task List Body ─────────────────────────────────────────────────────────────

class _TaskListBody extends StatelessWidget {
  const _TaskListBody({
    required this.tasks,
    required this.activeCount,
    required this.showSubmissionStatus,
    required this.submissionsByTaskId,
    required this.onRefresh,
    required this.onOpenTask,
  });

  final List<Task> tasks;
  final int activeCount;
  final bool showSubmissionStatus;
  final Map<int, Submission> submissionsByTaskId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Task task) onOpenTask;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: tasks.isEmpty ? 2 : tasks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _TaskSummaryCard(
                activeCount: activeCount,
                totalCount: tasks.length,
              ),
            );
          }

          if (tasks.isEmpty) {
            return const SizedBox(
              height: 360,
              child: EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No tasks yet',
                message: 'Assigned tasks will appear here.',
              ),
            );
          }

          final taskIndex = index - 1;
          final task = tasks[taskIndex];
          return AnimatedContainer(
            key: ValueKey<int>(task.id),
            duration: Duration(milliseconds: 180 + (taskIndex * 24)),
            curve: Curves.easeOutCubic,
            child: TaskListTile(
              task: task,
              submission: submissionsByTaskId[task.id],
              showSubmissionStatus: showSubmissionStatus,
              onTap: () => onOpenTask(task),
            ),
          );
        },
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({
    required this.activeCount,
    required this.totalCount,
  });

  final int activeCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.primary,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, Colors.black, 0.18)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$activeCount Active ${activeCount == 1 ? 'Task' : 'Tasks'}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalCount total ${totalCount == 1 ? 'assignment' : 'assignments'} in your workspace',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
