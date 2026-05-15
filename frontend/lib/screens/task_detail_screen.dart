import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/submission.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../widgets/app_page_route.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_action_button.dart';
import '../widgets/loading_state.dart';
import '../widgets/submission_list_tile.dart';
import 'submit_task_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.session,
    required this.taskId,
  });

  final AuthSession session;
  final int taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<Task> _taskFuture;
  late Future<List<Submission>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _taskFuture = widget.session.api.fetchTask(widget.taskId);
    _submissionsFuture = widget.session.api.fetchSubmissions(
      taskId: widget.taskId,
    );
  }

  void _refresh() {
    setState(_load);
  }

  Future<void> _openSubmit(Task task) async {
    final submitted = await Navigator.of(context).push<bool>(
      appPageRoute(
        SubmitTaskScreen(
          session: widget.session,
          task: task,
        ),
      ),
    );

    if (submitted == true) {
      _refresh();
    }
  }

  Future<void> _grade(Submission submission, int grade) async {
    try {
      await widget.session.api.gradeSubmission(
        submissionId: submission.id,
        grade: grade,
      );
      _refresh();
      if (!mounted) return;
      AppFeedback.success(context, 'Nilai berhasil disimpan.');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.toString());
    }
  }

  Future<void> _previewSubmissionFile(Submission submission) async {
    try {
      final file = await widget.session.api.downloadSubmissionFile(submission);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return _SubmissionFilePreviewDialog(
            file: file,
            onDownload: () => _saveDownloadedFile(file),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.toString());
    }
  }

  Future<void> _downloadSubmissionFile(Submission submission) async {
    try {
      final file = await widget.session.api.downloadSubmissionFile(submission);
      await _saveDownloadedFile(file);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.toString());
    }
  }

  Future<void> _saveDownloadedFile(DownloadedSubmissionFile file) async {
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan file pengumpulan',
      fileName: file.fileName,
      bytes: file.bytes,
    );
    if (!mounted) return;
    if (savedPath == null) {
      AppFeedback.error(context, 'Unduhan dibatalkan.');
    } else {
      AppFeedback.success(context, 'File berhasil disimpan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Task>(
          future: _taskFuture,
          builder: (context, snapshot) {
            return Text(
              snapshot.data?.title ?? 'Detail tugas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Task>(
        future: _taskFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList(itemCount: 4);
          }

          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final task = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 14),
              if (task.isClosed) ...[
                _ClosedTaskNotice(deadline: task.deadline),
                const SizedBox(height: 14),
              ],
              _DeadlineChip(deadline: task.deadline, isClosed: task.isClosed),
              const SizedBox(height: 22),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deskripsi',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        task.description.isEmpty
                            ? 'Tidak ada deskripsi.'
                            : task.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (user?.isStudent == true) ...[
                FutureBuilder<List<Submission>>(
                  future: _submissionsFuture,
                  builder: (context, snapshot) {
                    final submissions = snapshot.data ?? [];
                    final currentUserSubmission =
                        submissions.isEmpty ? null : submissions.first;
                    debugPrint(
                      'STUDENT SUBMISSION STATUS: '
                      'taskId=${task.id} '
                      'state=${snapshot.connectionState} '
                      'count=${submissions.length} '
                      'submissionId=${currentUserSubmission?.id}',
                    );
                    return _StudentSubmissionStatusCard(
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      submission: currentUserSubmission,
                      taskIsClosed: task.isClosed,
                    );
                  },
                ),
                const SizedBox(height: 16),
                GradientActionButton(
                  label: task.isClosed ? 'Tugas ditutup' : 'Kumpulkan tugas',
                  icon: Icons.upload_file_outlined,
                  onPressed: task.isClosed ? null : () => _openSubmit(task),
                ),
                const SizedBox(height: 24),
              ],
              if (user?.isTeacher == true) ...[
                FutureBuilder<List<Submission>>(
                  future: _submissionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SubmissionsHeader(count: 0),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      return AppErrorView(
                        message: snapshot.error.toString(),
                        onRetry: _refresh,
                      );
                    }

                    final submissions = snapshot.data ?? [];
                    debugPrint(
                      'SUBMISSIONS FUTURE BUILDER: '
                      'state=${snapshot.connectionState} '
                      'hasError=${snapshot.hasError} '
                      'length=${submissions.length}',
                    );
                    final header = _SubmissionsHeader(
                      count: submissions.length,
                    );
                    if (submissions.isEmpty) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SubmissionsHeader(count: 0),
                          SizedBox(height: 12),
                          SizedBox(
                            height: 220,
                            child: EmptyState(
                              icon: Icons.inbox_outlined,
                              title: 'Belum ada pengumpulan',
                              message:
                                  'Pengumpulan siswa akan muncul di sini.',
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            for (var index = 0;
                                index < submissions.length;
                                index++)
                              Builder(
                                builder: (context) {
                                  final submission = submissions[index];
                                  debugPrint(
                                    'SUBMISSION COLUMN ITEM: '
                                    'index=$index '
                                    'id=${submission.id} '
                                    'user=${submission.user.name} '
                                    'file=${submission.fileName} '
                                    'grade=${submission.grade}',
                                  );
                                  return SubmissionListTile(
                                    key: ValueKey<int>(submission.id),
                                    submission: submission,
                                    onPreviewFile: submission.hasFile
                                        ? () =>
                                            _previewSubmissionFile(submission)
                                        : null,
                                    onDownloadFile: submission.hasFile
                                        ? () =>
                                            _downloadSubmissionFile(submission)
                                        : null,
                                    onGrade: (grade) =>
                                        _grade(submission, grade),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StudentSubmissionStatusCard extends StatelessWidget {
  const _StudentSubmissionStatusCard({
    required this.isLoading,
    required this.submission,
    required this.taskIsClosed,
  });

  final bool isLoading;
  final Submission? submission;
  final bool taskIsClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final submittedAt = submission == null
        ? null
        : DateFormat('d MMM yyyy HH:mm').format(
            submission!.submittedAt.toLocal(),
          );
    final isSubmitted = submission != null;
    final color = isSubmitted
        ? Colors.green
        : taskIsClosed
            ? colorScheme.error
            : colorScheme.secondary;

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              isSubmitted
                  ? Icons.check_circle_outline
                  : taskIsClosed
                      ? Icons.lock_clock_outlined
                      : Icons.pending_actions_outlined,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading
                        ? 'Mengecek pengumpulan'
                        : isSubmitted
                            ? submission!.statusLabel
                            : taskIsClosed
                                ? 'Belum dikumpulkan'
                                : 'Belum dikumpulkan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isLoading
                        ? 'Mohon tunggu.'
                        : isSubmitted
                            ? 'Dikumpulkan pada $submittedAt'
                            : taskIsClosed
                                ? 'Deadline sudah lewat. Kamu tidak bisa mengumpulkan tugas ini lagi.'
                                : 'Unggah pekerjaan sebelum deadline.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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

class _ClosedTaskNotice extends StatelessWidget {
  const _ClosedTaskNotice({required this.deadline});

  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deadlineText = deadline == null
        ? null
        : DateFormat('d MMMM yyyy HH:mm').format(deadline!.toLocal());

    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_clock_outlined, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tugas sudah ditutup',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deadlineText == null
                        ? 'Tugas ini tidak menerima pengumpulan baru.'
                        : 'Deadline berakhir pada $deadlineText. Pengumpulan baru tidak tersedia.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      height: 1.35,
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

class _SubmissionFilePreviewDialog extends StatelessWidget {
  const _SubmissionFilePreviewDialog({
    required this.file,
    required this.onDownload,
  });

  final DownloadedSubmissionFile file;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(
        file.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: file.isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  file.bytes,
                  fit: BoxFit.contain,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    size: 56,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pratinjau tidak tersedia untuk tipe file ini.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${file.bytes.length} bytes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Unduh'),
        ),
      ],
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip({
    required this.deadline,
    required this.isClosed,
  });

  final DateTime? deadline;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgent = _isUrgent(deadline) && !isClosed;
    final text = deadline == null
        ? 'Tidak ada deadline'
        : DateFormat('EEEE, d MMMM yyyy HH:mm').format(deadline!.toLocal());
    final foreground = isClosed
        ? colorScheme.error
        : urgent
            ? colorScheme.error
            : colorScheme.primary;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foreground.withValues(alpha: 0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isClosed
                  ? Icons.lock_clock_outlined
                  : urgent
                      ? Icons.warning_amber_outlined
                      : Icons.event_outlined,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isUrgent(DateTime? value) {
    if (value == null) return false;
    return value.isBefore(DateTime.now().add(const Duration(hours: 24)));
  }
}

class _SubmissionsHeader extends StatelessWidget {
  const _SubmissionsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          'Pengumpulan',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(width: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              count.toString(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
