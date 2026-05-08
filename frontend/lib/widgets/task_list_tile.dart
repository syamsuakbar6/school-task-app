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
  });

  final Task task;
  final VoidCallback onTap;
  final Submission? submission;
  final bool showSubmissionStatus;

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
        ? 'No deadline'
        : DateFormat('EEE, d MMM yyyy HH:mm').format(task.deadline!.toLocal());
    final deadlineColor = isUrgent ? colorScheme.error : colorScheme.secondary;

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
                      color: colorScheme.primary,
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
                                  Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
        ? 'Submitted ${DateFormat('d MMM HH:mm').format(submission!.submittedAt.toLocal())}'
        : 'Not submitted';

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
          task.isClosed ? 'Closed' : 'Open',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
