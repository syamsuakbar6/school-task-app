import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';

class AdminPromotionPreviewScreen extends StatefulWidget {
  const AdminPromotionPreviewScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminPromotionPreviewScreen> createState() =>
      _AdminPromotionPreviewScreenState();
}

class _AdminPromotionPreviewScreenState
    extends State<AdminPromotionPreviewScreen> {
  late Future<List<Map<String, dynamic>>> _yearsFuture;
  Map<String, dynamic>? _preview;
  final Set<int> _notPromotedStudentIds = {};
  int? _sourceYearId;
  int? _targetYearId;
  bool _loadingPreview = false;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _yearsFuture = widget.session.api.adminListAcademicYears();
  }

  Future<void> _loadPreview() async {
    final sourceYearId = _sourceYearId;
    final targetYearId = _targetYearId;
    if (sourceYearId == null || targetYearId == null) {
      AppFeedback.error(context, 'Pilih tahun ajaran asal dan tujuan.');
      return;
    }
    if (sourceYearId == targetYearId) {
      AppFeedback.error(context, 'Tahun ajaran asal dan tujuan harus berbeda.');
      return;
    }

    setState(() {
      _loadingPreview = true;
      _preview = null;
      _notPromotedStudentIds.clear();
    });
    try {
      final preview = await widget.session.api.adminPreviewPromotion(
        sourceAcademicYearId: sourceYearId,
        targetAcademicYearId: targetYearId,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPreview = false);
      AppFeedback.error(context, e.toString());
    }
  }

  void _toggleStudent(int studentId, bool promoted) {
    setState(() {
      if (promoted) {
        _notPromotedStudentIds.remove(studentId);
      } else {
        _notPromotedStudentIds.add(studentId);
      }
    });
  }

  Future<void> _commitPromotion() async {
    final sourceYearId = _sourceYearId;
    final targetYearId = _targetYearId;
    final preview = _preview;
    if (sourceYearId == null || targetYearId == null || preview == null) {
      AppFeedback.error(context, 'Preview naik kelas belum tersedia.');
      return;
    }

    final studentCount = preview['student_count'] as int? ?? 0;
    final alumniCount = preview['alumni_count'] as int? ?? 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Naik Kelas'),
        content: Text(
          'Proses $studentCount siswa? ${_notPromotedStudentIds.length} siswa ditandai tidak naik dan $alumniCount siswa kelas XII akan menjadi alumni. Kelas asal akan diarsipkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Proses'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _committing = true);
    try {
      final result = await widget.session.api.adminCommitPromotion(
        sourceAcademicYearId: sourceYearId,
        targetAcademicYearId: targetYearId,
        notPromotedStudentIds: _notPromotedStudentIds.toList()..sort(),
      );
      if (!mounted) return;
      setState(() {
        _committing = false;
        _preview = null;
        _notPromotedStudentIds.clear();
        _yearsFuture = widget.session.api.adminListAcademicYears();
      });
      await _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _committing = false);
      AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _showResultDialog(Map<String, dynamic> result) async {
    final warnings = (result['warnings'] as List? ?? []).cast<Object>();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naik Kelas Selesai'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kelas baru dibuat: ${result['created_class_count'] ?? 0}'),
              Text('Kelas dipakai ulang: ${result['reused_class_count'] ?? 0}'),
              Text(
                  'Membership dibuat: ${result['membership_created_count'] ?? 0}'),
              Text('Alumni: ${result['alumni_count'] ?? 0}'),
              Text(
                  'Kelas asal diarsipkan: ${result['archived_class_count'] ?? 0}'),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Catatan:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                for (final warning in warnings)
                  Text(
                    '- $warning',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naik Kelas'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _yearsFuture = widget.session.api.adminListAcademicYears();
                _preview = null;
                _notPromotedStudentIds.clear();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _yearsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() {
                  _yearsFuture = widget.session.api.adminListAcademicYears();
                });
              },
            );
          }

          final years = snapshot.data ?? [];
          if (years.length < 2) {
            return const EmptyState(
              icon: Icons.trending_up,
              title: 'Tahun ajaran belum cukup',
              message:
                  'Tambahkan tahun ajaran tujuan sebelum preview naik kelas.',
            );
          }

          _sourceYearId ??= _activeYearId(years) ?? years.first['id'] as int?;
          _targetYearId ??= _firstOtherYearId(years, _sourceYearId);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _YearPickerCard(
                years: years,
                sourceYearId: _sourceYearId,
                targetYearId: _targetYearId,
                loading: _loadingPreview,
                onSourceChanged: (value) {
                  setState(() {
                    _sourceYearId = value;
                    if (_targetYearId == value) {
                      _targetYearId = _firstOtherYearId(years, value);
                    }
                    _preview = null;
                    _notPromotedStudentIds.clear();
                  });
                },
                onTargetChanged: (value) {
                  setState(() {
                    _targetYearId = value;
                    _preview = null;
                    _notPromotedStudentIds.clear();
                  });
                },
                onPreview: _loadPreview,
              ),
              const SizedBox(height: 12),
              if (_loadingPreview) const LoadingList(),
              if (_preview != null) ...[
                _PromotionPreviewView(
                  preview: _preview!,
                  notPromotedStudentIds: _notPromotedStudentIds,
                  onStudentChanged: _toggleStudent,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _committing ? null : _commitPromotion,
                    icon: _committing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Proses Naik Kelas'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  int? _activeYearId(List<Map<String, dynamic>> years) {
    for (final year in years) {
      if (year['is_active'] == true) return year['id'] as int?;
    }
    return null;
  }

  int? _firstOtherYearId(List<Map<String, dynamic>> years, int? sourceYearId) {
    for (final year in years) {
      final id = year['id'] as int?;
      if (id != null && id != sourceYearId) return id;
    }
    return null;
  }
}

class _YearPickerCard extends StatelessWidget {
  const _YearPickerCard({
    required this.years,
    required this.sourceYearId,
    required this.targetYearId,
    required this.loading,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onPreview,
  });

  final List<Map<String, dynamic>> years;
  final int? sourceYearId;
  final int? targetYearId;
  final bool loading;
  final ValueChanged<int?> onSourceChanged;
  final ValueChanged<int?> onTargetChanged;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: sourceYearId,
              decoration: const InputDecoration(labelText: 'Tahun asal'),
              items: _items(),
              onChanged: loading ? null : onSourceChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: targetYearId,
              decoration: const InputDecoration(labelText: 'Tahun tujuan'),
              items: _items(),
              onChanged: loading ? null : onTargetChanged,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading ? null : onPreview,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined),
                label: const Text('Preview'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _items() {
    return years
        .map((year) => DropdownMenuItem<int>(
              value: year['id'] as int,
              child: Text(year['name'] as String? ?? '-'),
            ))
        .toList();
  }
}

class _PromotionPreviewView extends StatelessWidget {
  const _PromotionPreviewView({
    required this.preview,
    required this.notPromotedStudentIds,
    required this.onStudentChanged,
  });

  final Map<String, dynamic> preview;
  final Set<int> notPromotedStudentIds;
  final void Function(int studentId, bool promoted) onStudentChanged;

  @override
  Widget build(BuildContext context) {
    final classes = (preview['classes'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final studentCount = preview['student_count'] as int? ?? 0;
    final alumniCount = preview['alumni_count'] as int? ?? 0;
    final reviewCount = preview['review_count'] as int? ?? 0;

    if (classes.isEmpty) {
      return const EmptyState(
        icon: Icons.class_outlined,
        title: 'Tidak ada kelas asal',
        message: 'Tidak ada kelas aktif pada tahun ajaran asal.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewSummary(
          studentCount: studentCount,
          alumniCount: alumniCount,
          reviewCount: reviewCount,
          retainedCount: notPromotedStudentIds.length,
        ),
        const SizedBox(height: 12),
        for (final classPreview in classes) ...[
          _PromotionClassCard(
            classPreview: classPreview,
            notPromotedStudentIds: notPromotedStudentIds,
            onStudentChanged: onStudentChanged,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({
    required this.studentCount,
    required this.alumniCount,
    required this.reviewCount,
    required this.retainedCount,
  });

  final int studentCount;
  final int alumniCount;
  final int reviewCount;
  final int retainedCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SummaryChip(icon: Icons.people_outline, label: '$studentCount siswa'),
        _SummaryChip(icon: Icons.school_outlined, label: '$alumniCount alumni'),
        _SummaryChip(
            icon: Icons.pause_circle_outline,
            label: '$retainedCount tidak naik'),
        if (reviewCount > 0)
          _SummaryChip(
              icon: Icons.error_outline, label: '$reviewCount perlu dicek'),
      ],
    );
  }
}

class _PromotionClassCard extends StatelessWidget {
  const _PromotionClassCard({
    required this.classPreview,
    required this.notPromotedStudentIds,
    required this.onStudentChanged,
  });

  final Map<String, dynamic> classPreview;
  final Set<int> notPromotedStudentIds;
  final void Function(int studentId, bool promoted) onStudentChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final students = (classPreview['students'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final defaultAction = classPreview['default_action'] as String? ?? '';
    final promotedTarget =
        classPreview['promoted_target_class_name'] as String?;
    final retainedTarget =
        classPreview['retained_target_class_name'] as String?;
    final warning = classPreview['warning'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.class_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classPreview['source_class_name'] as String? ?? '-',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _targetText(defaultAction, promotedTarget),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (warning != null && warning.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          warning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (students.isEmpty)
              Text(
                'Tidak ada siswa di kelas ini.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final student in students)
                _PromotionStudentTile(
                  student: student,
                  promoted:
                      !notPromotedStudentIds.contains(student['student_id']),
                  retainedTarget: retainedTarget,
                  onChanged: onStudentChanged,
                ),
          ],
        ),
      ),
    );
  }

  String _targetText(String defaultAction, String? promotedTarget) {
    if (defaultAction == 'graduate') return 'Default: lulus menjadi alumni';
    if (defaultAction == 'needs_review') return 'Default: perlu dicek manual';
    return 'Default: naik ke ${promotedTarget ?? '-'}';
  }
}

class _PromotionStudentTile extends StatelessWidget {
  const _PromotionStudentTile({
    required this.student,
    required this.promoted,
    required this.retainedTarget,
    required this.onChanged,
  });

  final Map<String, dynamic> student;
  final bool promoted;
  final String? retainedTarget;
  final void Function(int studentId, bool promoted) onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final studentId = student['student_id'] as int;
    final defaultAction = student['default_action'] as String? ?? '';
    final willBeAlumni = student['will_be_alumni'] as bool? ?? false;
    final promotedTarget = student['promoted_target_class_name'] as String?;
    final targetText = promoted
        ? _promotedText(defaultAction, willBeAlumni, promotedTarget)
        : 'Tidak naik: ${retainedTarget ?? '-'}';

    return CheckboxListTile(
      value: promoted,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (value) => onChanged(studentId, value ?? true),
      title: Text(student['name'] as String? ?? '-'),
      subtitle: Text(
        '${student['nisn'] ?? '-'} • $targetText',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      activeColor: colorScheme.primary,
    );
  }

  String _promotedText(
    String defaultAction,
    bool willBeAlumni,
    String? promotedTarget,
  ) {
    if (willBeAlumni || defaultAction == 'graduate')
      return 'Lulus menjadi alumni';
    if (defaultAction == 'needs_review') return 'Perlu dicek manual';
    return 'Naik ke ${promotedTarget ?? '-'}';
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
