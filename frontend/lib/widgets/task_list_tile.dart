import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/submission.dart';
import '../models/task.dart';

class TaskListTile extends StatefulWidget {
  const TaskListTile({
    super.key,
    required this.task,
    required this.onTap,
    this.submission,
    this.showSubmissionStatus = false,
    this.onHide,
    this.onRestore,
    this.showNewBadge = false,
  });

  final Task task;
  final VoidCallback onTap;
  final Submission? submission;
  final bool showSubmissionStatus;
  final VoidCallback? onHide;
  final VoidCallback? onRestore;
  final bool showNewBadge;

  @override
  State<TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<TaskListTile> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final task = widget.task;
    final submission = widget.submission;
    final isUrgent = _isUrgent(task.deadline) && !task.isClosed;
    final deadline = task.deadline == null
        ? 'Tidak ada deadline'
        : DateFormat('EEE, d MMM yyyy HH:mm').format(task.deadline!.toLocal());
    final deadlineColor = task.isClosed
        ? colorScheme.onSurfaceVariant
        : isUrgent
            ? colorScheme.error
            : colorScheme.secondary;
    final sideColor = task.isClosed
        ? colorScheme.outlineVariant
        : widget.showNewBadge
            ? colorScheme.tertiary
            : colorScheme.primary;

    return AnimatedScale(
      scale: _isPressed || _isHovered ? 0.98 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTapUp: (_) => setState(() => _isPressed = false),
          child: Card(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: sideColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: task.isClosed
                                                ? colorScheme.onSurfaceVariant
                                                : colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (widget.showNewBadge) ...[
                                        const SizedBox(width: 8),
                                        const _NewTaskBadge(),
                                      ],
                                    ],
                                  ),
                                  if (task.isClosed) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Deadline sudah lewat',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  if (!widget.showSubmissionStatus &&
                                      task.creatorName != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Dibuat oleh ${task.creatorName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        isUrgent
                                            ? Icons.warning_amber_outlined
                                            : Icons.schedule_outlined,
                                        size: 17,
                                        color: deadlineColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          deadline,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: deadlineColor,
                                            fontWeight: isUrgent
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (widget.showSubmissionStatus) ...[
                                    const SizedBox(height: 8),
                                    _SubmissionStatusLine(
                                      submission: submission,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _TaskStatusChip(task: task),
                                const SizedBox(height: 8),
                                if (widget.onRestore != null)
                                  IconButton(
                                    tooltip: 'Tampilkan lagi',
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.visibility_outlined,
                                      size: 20,
                                      color: colorScheme.primary,
                                    ),
                                    onPressed: widget.onRestore,
                                  )
                                else if (widget.onHide != null)
                                  IconButton(
                                    tooltip: 'Sembunyikan dari daftar',
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: colorScheme.error,
                                    ),
                                    onPressed: widget.onHide,
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isUrgent(DateTime? deadline) {
    if (deadline == null) return false;
    final now = DateTime.now();
    return deadline.isBefore(now.add(const Duration(hours: 24)));
  }
}

class _SubmissionStatusLine extends StatelessWidget {
  const _SubmissionStatusLine({required this.submission});

  final Submission? submission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final submitted = submission != null;
    final color = submitted ? Colors.green : colorScheme.onSurfaceVariant;
    final text = submitted
        ? 'Dikumpulkan ${DateFormat('d MMM HH:mm').format(submission!.submittedAt.toLocal())}'
        : 'Belum dikumpulkan';

    return Row(
      children: [
        Icon(
          submitted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: submitted ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = task.isClosed
        ? colorScheme.surfaceContainer
        : colorScheme.primaryContainer.withValues(alpha: 0.68);
    final foregroundColor =
        task.isClosed ? colorScheme.onSurfaceVariant : colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          task.isClosed ? 'Ditutup' : 'Dibuka',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _NewTaskBadge extends StatelessWidget {
  const _NewTaskBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Baru',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}
