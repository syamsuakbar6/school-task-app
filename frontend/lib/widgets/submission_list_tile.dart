import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/submission.dart';

class SubmissionListTile extends StatelessWidget {
  const SubmissionListTile({
    super.key,
    required this.submission,
    required this.onGrade,
    this.onPreviewFile,
    this.onDownloadFile,
  });

  final Submission submission;
  final ValueChanged<int> onGrade;
  final VoidCallback? onPreviewFile;
  final VoidCallback? onDownloadFile;

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'BUILD SUBMISSION TILE: '
      'id=${submission.id} '
      'user="${submission.user.name}" '
      'file="${submission.fileName}" '
      'downloadUrl="${submission.downloadUrl}" '
      'grade=${submission.grade} '
      'hasFile=${submission.hasFile}',
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final submittedAt = DateFormat(
      'd MMM yyyy HH:mm',
    ).format(submission.submittedAt.toLocal());
    final fileName = submission.fileName ?? 'Tidak ada file';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.primary,
              child: Text(
                _initials(submission.user.name),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    submittedAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (submission.hasFile) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _FileAction(
                          icon: Icons.visibility_outlined,
                          label: 'Lihat',
                          onPressed: onPreviewFile,
                        ),
                        _FileAction(
                          icon: Icons.download_outlined,
                          label: 'Unduh',
                          onPressed: onDownloadFile,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _GradeAction(
              grade: submission.grade,
              onPressed: () => _showGradeDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Future<void> _showGradeDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: submission.grade?.toString() ?? '',
    );
    String? errorText;

    final grade = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Beri nilai pengumpulan'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nilai',
                  helperText: 'Masukkan angka 0 sampai 100',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    if (value == null || value < 0 || value > 100) {
                      setDialogState(() {
                        errorText = 'Nilai harus berupa angka 0 sampai 100.';
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (grade != null) {
      onGrade(grade);
    }
  }
}

class _GradeAction extends StatelessWidget {
  const _GradeAction({
    required this.grade,
    required this.onPressed,
  });

  final int? grade;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasGrade = grade != null;

    if (hasGrade) {
      return Material(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Nilai $grade',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: Colors.amber.shade800,
        side: BorderSide(color: Colors.amber.shade700),
      ),
      child: Text(
        'Beri nilai',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.brightness == Brightness.dark
              ? Colors.amber.shade300
              : Colors.amber.shade800,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FileAction extends StatelessWidget {
  const _FileAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
