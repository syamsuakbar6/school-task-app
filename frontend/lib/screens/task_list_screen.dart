import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/submission.dart';
import '../models/task.dart';
import '../services/auth_session.dart';
import '../services/notification_service.dart';
import '../theme/theme_mode_scope.dart';
import '../widgets/app_page_route.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/task_list_tile.dart';
import 'change_password_screen.dart';
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
  Set<int> _hiddenTaskIds = {};

  // Multi-class (teacher only)
  List<Map<String, dynamic>> _classes = [];
  int? _selectedClassId;
  bool _classesLoaded = false;

  @override
  void initState() {
    super.initState();
    _tasksFuture = Future.value(const <Task>[]);
    _initLoad();
  }

  Future<void> _initLoad() async {
    if (widget.session.user?.isStudent == true) {
      await _loadHiddenTaskIds();
    }
    if (widget.session.user?.isTeacher == true) {
      await _loadClasses();
    } else {
      _load();
    }
    // Cek deadline saat app dibuka (in-app check)
    await NotificationService.checkAndNotifyDeadlines();
  }

  Future<void> _loadHiddenTaskIds() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_hiddenTasksKey()) ?? const <String>[];
    _hiddenTaskIds = values
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  String _hiddenTasksKey() {
    return 'hidden_task_ids_user_${widget.session.user?.id ?? 0}';
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await widget.session.api.fetchClasses();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _classesLoaded = true;
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
      _tasksFuture = _fetchAndCacheTasks();
      _studentSubmissionsFuture = widget.session.user?.isStudent == true
          ? widget.session.api.fetchSubmissions()
          : null;
    });
  }

  /// Fetch tasks dari API, sort by deadline, lalu cache untuk notifikasi.
  Future<List<Task>> _fetchAndCacheTasks() async {
    var tasks = await widget.session.api.fetchTasks(
      classId: _selectedClassId,
    );

    if (widget.session.user?.isStudent == true && _hiddenTaskIds.isNotEmpty) {
      tasks = tasks.where((task) => !_hiddenTaskIds.contains(task.id)).toList();
    }

    // Sort: tugas aktif di atas, lalu deadline terdekat.
    tasks.sort((a, b) {
      if (a.isClosed != b.isClosed) {
        return a.isClosed ? 1 : -1;
      }
      if (a.deadline == null && b.deadline == null) return 0;
      if (a.deadline == null) return 1; // a ke bawah
      if (b.deadline == null) return -1; // b ke bawah
      return a.deadline!.compareTo(b.deadline!);
    });

    // Cache task untuk background notification service
    // Hanya untuk student (yang perlu submit)
    if (widget.session.user?.isStudent == true) {
      await _cacheTasksForNotification(tasks);
    }

    return tasks;
  }

  /// Simpan task ke cache dengan format yang dibutuhkan NotificationService.
  Future<void> _cacheTasksForNotification(List<Task> tasks) async {
    // Ambil submission student untuk tahu mana yang sudah disubmit
    List<Submission> submissions = [];
    try {
      submissions = await widget.session.api.fetchSubmissions();
    } catch (_) {}

    final submittedTaskIds = submissions.map((s) => s.taskId).toSet();

    final taskMaps = tasks
        .where((t) => t.deadline != null && !t.isClosed)
        .map((t) => {
              'id': t.id,
              'title': t.title,
              'deadline': t.deadline?.toUtc().toIso8601String(),
              'submitted': submittedTaskIds.contains(t.id),
            })
        .toList();

    await NotificationService.cacheTasks(taskMaps);
  }

  void _refresh() {
    if (widget.session.user?.isTeacher == true) {
      _loadClasses();
    } else {
      _load();
    }
  }

  Future<void> _reloadTasks() async {
    final nextTasks = _fetchAndCacheTasks();
    final nextSubmissions = widget.session.user?.isStudent == true
        ? widget.session.api.fetchSubmissions()
        : null;
    setState(() {
      _tasksFuture = nextTasks;
      _studentSubmissionsFuture = nextSubmissions;
    });
    await nextTasks;
    if (nextSubmissions != null) await nextSubmissions;
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
    if (created == true) await _reloadTasks();
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

  Future<void> _hideTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus dari List'),
        content: Text(
          'Hapus tugas "${task.title}" dari list kamu? Data tugas dan submission tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    _hiddenTaskIds.add(task.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _hiddenTasksKey(),
      _hiddenTaskIds.map((id) => id.toString()).toList(),
    );
    await _reloadTasks();
    if (mounted) {
      AppFeedback.success(context, 'Tugas dihapus dari list.');
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
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: () =>
                themeModeController.toggleFromBrightness(theme.brightness),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
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
            tooltip: 'Ganti password',
            onPressed: () => Navigator.of(context).push(
              appPageRoute(ChangePasswordScreen(session: widget.session)),
            ),
            icon: const Icon(Icons.lock_reset_outlined),
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
            return const LoadingList();
          }

          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final tasks = snapshot.data ?? [];
          final activeCount = tasks.where((t) => !t.isClosed).length;

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
                  onHideTask: _hideTask,
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
            onHideTask: null,
          );
        },
      ),
    );
  }

  Map<int, Submission> _latestSubmissionByTaskId(List<Submission> submissions) {
    final byTaskId = <int, Submission>{};
    for (final s in submissions) {
      final current = byTaskId[s.taskId];
      if (current == null || s.submittedAt.isAfter(current.submittedAt)) {
        byTaskId[s.taskId] = s;
      }
    }
    return byTaskId;
  }
}

// ── Class Dropdown ────────────────────────────────────────────────────────────

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
        icon: Icon(Icons.arrow_drop_down,
            size: 16, color: colorScheme.onSurfaceVariant),
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

// ── Task List Body ────────────────────────────────────────────────────────────

class _TaskListBody extends StatelessWidget {
  const _TaskListBody({
    required this.tasks,
    required this.activeCount,
    required this.showSubmissionStatus,
    required this.submissionsByTaskId,
    required this.onRefresh,
    required this.onOpenTask,
    required this.onHideTask,
  });

  final List<Task> tasks;
  final int activeCount;
  final bool showSubmissionStatus;
  final Map<int, Submission> submissionsByTaskId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Task task) onOpenTask;
  final Future<void> Function(Task task)? onHideTask;

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
                title: 'Belum ada tugas',
                message: 'Tugas yang diberikan akan muncul di sini.',
              ),
            );
          }

          final taskIndex = index - 1;
          final task = tasks[taskIndex];
          final submission = submissionsByTaskId[task.id];
          final showNewBadge =
              showSubmissionStatus && !task.isClosed && submission == null;
          final canHide = showSubmissionStatus &&
              onHideTask != null &&
              (task.isClosed || submission != null);
          return AnimatedContainer(
            key: ValueKey<int>(task.id),
            duration: Duration(milliseconds: 180 + (taskIndex * 24)),
            curve: Curves.easeOutCubic,
            child: TaskListTile(
              task: task,
              submission: submission,
              showSubmissionStatus: showSubmissionStatus,
              onTap: () => onOpenTask(task),
              onHide: canHide ? () => onHideTask!(task) : null,
              showNewBadge: showNewBadge,
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
          borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_outlined, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$activeCount Tugas Aktif',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalCount total tugas • aktif selalu di atas',
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
