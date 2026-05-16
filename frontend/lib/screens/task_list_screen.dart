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

enum _TaskFilter { active, newTasks, submitted, graded, closed }

enum _TeacherTaskScope { mine, classAll }

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Task>> _tasksFuture;
  Future<List<Submission>>? _studentSubmissionsFuture;
  Set<int> _hiddenTaskIds = {};
  final _searchController = TextEditingController();
  _TaskFilter _taskFilter = _TaskFilter.active;
  String _searchQuery = '';
  bool _showHiddenOnly = false;
  bool _studentClassesLoaded = false;
  bool _studentHasClass = true;
  _TeacherTaskScope _teacherTaskScope = _TeacherTaskScope.mine;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    if (widget.session.user?.isStudent == true) {
      await _loadHiddenTaskIds();
      await _loadStudentClassState();
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
    _hiddenTaskIds = values.map(int.tryParse).whereType<int>().toSet();
  }

  String _hiddenTasksKey() {
    return 'hidden_task_ids_user_${widget.session.user?.id ?? 0}';
  }

  Future<void> _loadStudentClassState() async {
    try {
      final classes = await widget.session.api.fetchClasses();
      if (!mounted) return;
      setState(() {
        _studentClassesLoaded = true;
        _studentHasClass = classes.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _studentClassesLoaded = true;
        _studentHasClass = true;
      });
    }
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
              'hidden': _hiddenTaskIds.contains(t.id),
            })
        .toList();

    await NotificationService.cacheTasks(taskMaps);
  }

  void _refresh() {
    if (widget.session.user?.isTeacher == true) {
      _loadClasses();
    } else if (widget.session.user?.isStudent == true) {
      _loadStudentClassState();
      _load();
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
        title: const Text('Sembunyikan tugas'),
        content: Text(
          'Sembunyikan "${task.title}" dari daftar kamu? Data tugas dan pengumpulan tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sembunyikan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    _hiddenTaskIds.add(task.id);
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _hiddenTasksKey(),
      _hiddenTaskIds.map((id) => id.toString()).toList(),
    );
    await _reloadTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tugas disembunyikan dari daftar.'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () => _restoreTask(task),
          ),
        ),
      );
    }
  }

  Future<void> _restoreTask(Task task) async {
    _hiddenTaskIds.remove(task.id);
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _hiddenTasksKey(),
      _hiddenTaskIds.map((id) => id.toString()).toList(),
    );
    await _reloadTasks();
    if (mounted) {
      AppFeedback.success(context, 'Tugas kembali ditampilkan.');
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
              isTeacher ? 'Tugas Kelas' : 'Daftar Tugas',
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
                'Halo, ${user?.name ?? 'Siswa'}',
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
            tooltip: 'Muat ulang',
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
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed:
                  _classesLoaded && _classes.isEmpty ? null : _openCreateTask,
              icon: const Icon(Icons.add),
              label: const Text('Tugas'),
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
          if (user?.isStudent == true && _studentSubmissionsFuture != null) {
            return FutureBuilder<List<Submission>>(
              future: _studentSubmissionsFuture,
              builder: (context, submissionsSnapshot) {
                final submissions = submissionsSnapshot.data ?? [];
                return _TaskListBody(
                  tasks: tasks,
                  filter: _taskFilter,
                  searchQuery: _searchQuery,
                  showHiddenOnly: _showHiddenOnly,
                  hiddenTaskIds: _hiddenTaskIds,
                  hiddenCount: _hiddenTaskIds.length,
                  emptyTitle: _studentClassesLoaded && !_studentHasClass
                      ? 'Belum terdaftar di kelas'
                      : null,
                  emptyMessage: _studentClassesLoaded && !_studentHasClass
                      ? 'Minta admin menambahkan akun kamu ke kelas agar tugas bisa muncul.'
                      : null,
                  showSubmissionStatus: true,
                  teacherTaskScope: _TeacherTaskScope.classAll,
                  currentTeacherId: null,
                  submissionsByTaskId: _latestSubmissionByTaskId(submissions),
                  onRefresh: _reloadTasks,
                  onOpenTask: _openTaskDetail,
                  onHideTask: _hideTask,
                  onRestoreTask: _restoreTask,
                  onFilterChanged: (filter) {
                    setState(() => _taskFilter = filter);
                  },
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  onHiddenToggle: (value) {
                    setState(() => _showHiddenOnly = value);
                  },
                  onTeacherScopeChanged: null,
                  searchController: _searchController,
                );
              },
            );
          }

          return _TaskListBody(
            tasks: tasks,
            filter: _TaskFilter.active,
            searchQuery: _searchQuery,
            showHiddenOnly: false,
            hiddenTaskIds: const {},
            hiddenCount: 0,
            emptyTitle: isTeacher && _classesLoaded && _classes.isEmpty
                ? 'Belum ada kelas yang ditugaskan'
                : null,
            emptyMessage: isTeacher && _classesLoaded && _classes.isEmpty
                ? 'Minta admin menambahkan akun guru ini ke kelas sebelum membuat atau melihat tugas.'
                : null,
            showSubmissionStatus: false,
            teacherTaskScope: _teacherTaskScope,
            currentTeacherId: user?.id,
            submissionsByTaskId: const {},
            onRefresh: _reloadTasks,
            onOpenTask: _openTaskDetail,
            onHideTask: null,
            onRestoreTask: null,
            onFilterChanged: null,
            onSearchChanged: (value) {
              setState(() => _searchQuery = value);
            },
            onHiddenToggle: null,
            onTeacherScopeChanged: (scope) {
              setState(() => _teacherTaskScope = scope);
            },
            searchController: _searchController,
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
    required this.filter,
    required this.searchQuery,
    required this.showHiddenOnly,
    required this.hiddenTaskIds,
    required this.hiddenCount,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.showSubmissionStatus,
    required this.teacherTaskScope,
    required this.currentTeacherId,
    required this.submissionsByTaskId,
    required this.onRefresh,
    required this.onOpenTask,
    required this.onHideTask,
    required this.onRestoreTask,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onHiddenToggle,
    required this.onTeacherScopeChanged,
    required this.searchController,
  });

  final List<Task> tasks;
  final _TaskFilter filter;
  final String searchQuery;
  final bool showHiddenOnly;
  final Set<int> hiddenTaskIds;
  final int hiddenCount;
  final String? emptyTitle;
  final String? emptyMessage;
  final bool showSubmissionStatus;
  final _TeacherTaskScope teacherTaskScope;
  final int? currentTeacherId;
  final Map<int, Submission> submissionsByTaskId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Task task) onOpenTask;
  final Future<void> Function(Task task)? onHideTask;
  final Future<void> Function(Task task)? onRestoreTask;
  final ValueChanged<_TaskFilter>? onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool>? onHiddenToggle;
  final ValueChanged<_TeacherTaskScope>? onTeacherScopeChanged;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final visibleTasks = tasks.where((task) {
      final hidden = hiddenTaskIds.contains(task.id);
      if (showSubmissionStatus) {
        if (showHiddenOnly && !hidden) return false;
        if (!showHiddenOnly && hidden) return false;
      }

      if (query.isNotEmpty) {
        final haystack = '${task.title} ${task.description}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }

      if (!showSubmissionStatus &&
          teacherTaskScope == _TeacherTaskScope.mine &&
          currentTeacherId != null &&
          task.createdBy != currentTeacherId) {
        return false;
      }

      if (!showSubmissionStatus) return true;
      final submission = submissionsByTaskId[task.id];
      switch (filter) {
        case _TaskFilter.active:
          return !task.isClosed;
        case _TaskFilter.newTasks:
          return !task.isClosed && submission == null;
        case _TaskFilter.submitted:
          return submission != null && submission.grade == null;
        case _TaskFilter.graded:
          return submission?.grade != null;
        case _TaskFilter.closed:
          return task.isClosed;
      }
    }).toList();

    final activeCount = visibleTasks.where((task) => !task.isClosed).length;
    final resolvedEmptyTitle = emptyTitle ??
        (showHiddenOnly
            ? 'Tidak ada tugas tersembunyi'
            : query.isNotEmpty
                ? 'Tugas tidak ditemukan'
                : _emptyTitleForFilter(filter, showSubmissionStatus));
    final resolvedEmptyMessage = emptyMessage ??
        (showHiddenOnly
            ? 'Tugas yang kamu sembunyikan akan muncul di sini.'
            : query.isNotEmpty
                ? 'Coba kata kunci lain atau ubah filter.'
                : _emptyMessageForFilter(filter, showSubmissionStatus));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: visibleTasks.isEmpty ? 2 : visibleTasks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                children: [
                  _TaskControls(
                    isStudent: showSubmissionStatus,
                    filter: filter,
                    hiddenCount: hiddenCount,
                    showHiddenOnly: showHiddenOnly,
                    searchController: searchController,
                    onFilterChanged: onFilterChanged,
                    onSearchChanged: onSearchChanged,
                    onHiddenToggle: onHiddenToggle,
                    teacherTaskScope: teacherTaskScope,
                    onTeacherScopeChanged: onTeacherScopeChanged,
                  ),
                  const SizedBox(height: 14),
                  _TaskSummaryCard(
                    activeCount: activeCount,
                    totalCount: visibleTasks.length,
                    showSubmissionStatus: showSubmissionStatus,
                  ),
                ],
              ),
            );
          }

          if (visibleTasks.isEmpty) {
            return SizedBox(
              height: 360,
              child: EmptyState(
                icon: Icons.assignment_outlined,
                title: resolvedEmptyTitle,
                message: resolvedEmptyMessage,
              ),
            );
          }

          final taskIndex = index - 1;
          final task = visibleTasks[taskIndex];
          final submission = submissionsByTaskId[task.id];
          final showNewBadge =
              showSubmissionStatus && !task.isClosed && submission == null;
          final isHidden = hiddenTaskIds.contains(task.id);
          final canHide = showSubmissionStatus &&
              onHideTask != null &&
              !isHidden &&
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
              onRestore: isHidden && onRestoreTask != null
                  ? () => onRestoreTask!(task)
                  : null,
              showNewBadge: showNewBadge,
            ),
          );
        },
      ),
    );
  }

  String _emptyTitleForFilter(_TaskFilter filter, bool isStudent) {
    if (!isStudent) return 'Belum ada tugas';
    switch (filter) {
      case _TaskFilter.active:
        return 'Belum ada tugas aktif';
      case _TaskFilter.newTasks:
        return 'Tidak ada tugas baru';
      case _TaskFilter.submitted:
        return 'Belum ada tugas terkumpul';
      case _TaskFilter.graded:
        return 'Belum ada tugas dinilai';
      case _TaskFilter.closed:
        return 'Belum ada tugas ditutup';
    }
  }

  String _emptyMessageForFilter(_TaskFilter filter, bool isStudent) {
    if (!isStudent) return 'Tugas yang dibuat akan muncul di sini.';
    switch (filter) {
      case _TaskFilter.active:
        return 'Tugas aktif dari kelas kamu akan muncul di sini.';
      case _TaskFilter.newTasks:
        return 'Semua tugas aktif sudah kamu kumpulkan atau belum ada tugas baru.';
      case _TaskFilter.submitted:
        return 'Tugas yang sudah dikumpulkan dan belum dinilai akan muncul di sini.';
      case _TaskFilter.graded:
        return 'Nilai dari guru akan muncul setelah pengumpulan diperiksa.';
      case _TaskFilter.closed:
        return 'Tugas yang deadlinenya sudah lewat akan muncul di sini.';
    }
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _TaskControls extends StatelessWidget {
  const _TaskControls({
    required this.isStudent,
    required this.filter,
    required this.hiddenCount,
    required this.showHiddenOnly,
    required this.searchController,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onHiddenToggle,
    required this.teacherTaskScope,
    required this.onTeacherScopeChanged,
  });

  final bool isStudent;
  final _TaskFilter filter;
  final int hiddenCount;
  final bool showHiddenOnly;
  final TextEditingController searchController;
  final ValueChanged<_TaskFilter>? onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool>? onHiddenToggle;
  final _TeacherTaskScope teacherTaskScope;
  final ValueChanged<_TeacherTaskScope>? onTeacherScopeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Cari judul atau deskripsi',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Bersihkan pencarian',
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        if (isStudent) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipButton(
                  label: 'Aktif',
                  selected: filter == _TaskFilter.active,
                  onSelected: () => onFilterChanged?.call(_TaskFilter.active),
                ),
                _FilterChipButton(
                  label: 'Baru',
                  selected: filter == _TaskFilter.newTasks,
                  onSelected: () => onFilterChanged?.call(
                    _TaskFilter.newTasks,
                  ),
                ),
                _FilterChipButton(
                  label: 'Terkumpul',
                  selected: filter == _TaskFilter.submitted,
                  onSelected: () => onFilterChanged?.call(
                    _TaskFilter.submitted,
                  ),
                ),
                _FilterChipButton(
                  label: 'Dinilai',
                  selected: filter == _TaskFilter.graded,
                  onSelected: () => onFilterChanged?.call(
                    _TaskFilter.graded,
                  ),
                ),
                _FilterChipButton(
                  label: 'Ditutup',
                  selected: filter == _TaskFilter.closed,
                  onSelected: () => onFilterChanged?.call(_TaskFilter.closed),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: showHiddenOnly,
                  onSelected: hiddenCount == 0 ? null : onHiddenToggle,
                  avatar: Icon(
                    showHiddenOnly
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  label: Text('Tersembunyi ($hiddenCount)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            showHiddenOnly
                ? 'Menampilkan tugas yang kamu sembunyikan.'
                : 'Tugas terkumpul atau ditutup bisa disembunyikan dari daftar.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ] else if (onTeacherScopeChanged != null) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TeacherScopeChip(
                  label: 'Tugas saya',
                  selected: teacherTaskScope == _TeacherTaskScope.mine,
                  onSelected: () =>
                      onTeacherScopeChanged!(_TeacherTaskScope.mine),
                ),
                _TeacherScopeChip(
                  label: 'Semua tugas kelas',
                  selected: teacherTaskScope == _TeacherTaskScope.classAll,
                  onSelected: () =>
                      onTeacherScopeChanged!(_TeacherTaskScope.classAll),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TeacherScopeChip extends StatelessWidget {
  const _TeacherScopeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({
    required this.activeCount,
    required this.totalCount,
    required this.showSubmissionStatus,
  });

  final int activeCount;
  final int totalCount;
  final bool showSubmissionStatus;

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
                    showSubmissionStatus
                        ? '$totalCount Tugas'
                        : '$activeCount Tugas Aktif',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    showSubmissionStatus
                        ? '$activeCount masih aktif dari daftar ini'
                        : '$totalCount tugas ditampilkan, aktif selalu di atas',
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
