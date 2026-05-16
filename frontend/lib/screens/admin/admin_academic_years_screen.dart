import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';

class AdminAcademicYearsScreen extends StatefulWidget {
  const AdminAcademicYearsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminAcademicYearsScreen> createState() =>
      _AdminAcademicYearsScreenState();
}

class _AdminAcademicYearsScreenState extends State<AdminAcademicYearsScreen> {
  late Future<List<Map<String, dynamic>>> _yearsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _yearsFuture = widget.session.api.adminListAcademicYears();
    });
  }

  DateTime? _parseIsoDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String _formatIsoDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String? _validateOptionalDate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (_parseIsoDate(text) == null) {
      return 'Tanggal harus valid dengan format YYYY-MM-DD';
    }
    return null;
  }

  Future<void> _pickDate(
    TextEditingController controller,
    StateSetter setDialogState,
  ) async {
    final current = _parseIsoDate(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked == null) return;
    setDialogState(() {
      controller.text = _formatIsoDate(picked);
    });
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final startsController = TextEditingController();
    final endsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool isActive = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Tahun Ajaran'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Tahun Ajaran',
                      hintText: 'contoh: 2026/2027',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().length < 3) {
                        return 'Nama tahun ajaran minimal 3 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: startsController,
                    readOnly: true,
                    onTap: saving
                        ? null
                        : () => _pickDate(startsController, setDialogState),
                    decoration: InputDecoration(
                      labelText: 'Tanggal mulai',
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: const Icon(Icons.event_outlined),
                      suffixIcon: startsController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Kosongkan tanggal mulai',
                              onPressed: saving
                                  ? null
                                  : () {
                                      setDialogState(startsController.clear);
                                    },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    validator: _validateOptionalDate,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: endsController,
                    readOnly: true,
                    onTap: saving
                        ? null
                        : () => _pickDate(endsController, setDialogState),
                    decoration: InputDecoration(
                      labelText: 'Tanggal selesai',
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: const Icon(Icons.event_available_outlined),
                      suffixIcon: endsController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Kosongkan tanggal selesai',
                              onPressed: saving
                                  ? null
                                  : () {
                                      setDialogState(endsController.clear);
                                    },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    validator: _validateOptionalDate,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: const Text('Jadikan aktif'),
                    onChanged: saving
                        ? null
                        : (value) {
                            setDialogState(() => isActive = value);
                          },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final startsAt = startsController.text.trim();
                      final endsAt = endsController.text.trim();
                      final startDate =
                          startsAt.isEmpty ? null : _parseIsoDate(startsAt);
                      final endDate =
                          endsAt.isEmpty ? null : _parseIsoDate(endsAt);
                      if (startDate != null &&
                          endDate != null &&
                          startDate.isAfter(endDate)) {
                        setDialogState(() {
                          error =
                              'Tanggal mulai tidak boleh setelah tanggal selesai.';
                        });
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await widget.session.api.adminCreateAcademicYear(
                          name: nameController.text.trim(),
                          startsAt: startsAt.isEmpty ? null : startsAt,
                          endsAt: endsAt.isEmpty ? null : endsAt,
                          isActive: isActive,
                        );
                        if (context.mounted) Navigator.pop(context);
                        _refresh();
                        if (mounted) {
                          AppFeedback.success(
                            this.context,
                            'Tahun ajaran berhasil ditambahkan.',
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          error = e.toString();
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    startsController.dispose();
    endsController.dispose();
  }

  Future<void> _activate(Map<String, dynamic> year) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktifkan Tahun Ajaran'),
        content: Text(
          'Jadikan ${year['name']} sebagai tahun ajaran aktif?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.session.api.adminActivateAcademicYear(year['id'] as int);
      _refresh();
      if (mounted) {
        AppFeedback.success(context, '${year['name']} sekarang aktif.');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tahun Ajaran'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
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
              onRetry: _refresh,
            );
          }

          final years = snapshot.data ?? [];
          if (years.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Belum ada tahun ajaran',
              message: 'Ketuk tombol di bawah untuk menambahkan tahun ajaran.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: years.length,
            itemBuilder: (context, index) {
              final year = years[index];
              final isActive = year['is_active'] as bool? ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    year['name'] as String? ?? '-',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    _periodText(year),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isActive
                      ? const _ActiveChip()
                      : OutlinedButton(
                          onPressed: () => _activate(year),
                          child: const Text('Aktifkan'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _periodText(Map<String, dynamic> year) {
    final startsAt = year['starts_at'] as String?;
    final endsAt = year['ends_at'] as String?;
    if ((startsAt == null || startsAt.isEmpty) &&
        (endsAt == null || endsAt.isEmpty)) {
      return 'Periode belum diisi';
    }
    return '${startsAt ?? '-'} sampai ${endsAt ?? '-'}';
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'Aktif',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
