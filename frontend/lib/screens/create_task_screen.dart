import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_session.dart';
import '../widgets/gradient_action_button.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _deadline;
  late Future<List<Map<String, dynamic>>> _classesFuture;
  int? _selectedClassId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _classesFuture = _loadClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadClasses() async {
    final classes = await widget.session.api.fetchClasses();
    if (_selectedClassId == null && classes.isNotEmpty) {
      _selectedClassId = classes.first['id'] as int;
    }
    return classes;
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: _deadline ?? now,
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
    );

    final selectedDeadline = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 23,
      time?.minute ?? 59,
    );

    if (selectedDeadline.isBefore(DateTime.now())) {
      setState(() {
        _errorMessage = 'Deadline tidak boleh lebih awal dari waktu sekarang.';
      });
      return;
    }

    setState(() {
      _deadline = selectedDeadline;
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final classId = _selectedClassId;
    if (classId == null) {
      setState(() => _errorMessage = 'Pilih kelas terlebih dahulu.');
      return;
    }
    if (_deadline != null && _deadline!.isBefore(DateTime.now())) {
      setState(() {
        _errorMessage = 'Deadline tidak boleh lebih awal dari waktu sekarang.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.session.api.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        deadline: _deadline,
        classId: classId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Buat Tugas',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.primary,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (_errorMessage != null) ...[
              _CreateTaskError(message: _errorMessage!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 3) {
                  return 'Judul minimal 3 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _classesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ClassLoadingField();
                }
                if (snapshot.hasError) {
                  return _ClassErrorField(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(() {
                      _classesFuture = _loadClasses();
                    }),
                  );
                }

                final classes = snapshot.data ?? [];
                if (classes.isEmpty) {
                  return const _ClassErrorField(
                    message: 'Belum ada kelas yang ditugaskan ke akun guru ini.',
                  );
                }

                return DropdownButtonFormField<int>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: classes.map((classData) {
                    final id = classData['id'] as int;
                    final name = classData['name'] as String? ?? 'Kelas $id';
                    final code = classData['code'] as String? ?? '-';
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        '$name ($code)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _selectedClassId = value),
                  validator: (value) {
                    if (value == null) return 'Pilih kelas';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            _DeadlinePickerCard(
              deadline: _deadline,
              onPressed: _isSaving ? null : _pickDeadline,
              onClear: _isSaving || _deadline == null
                  ? null
                  : () => setState(() => _deadline = null),
            ),
            const SizedBox(height: 24),
            GradientActionButton(
              label: 'Buat tugas',
              icon: Icons.save_outlined,
              onPressed: _isSaving ? null : _save,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlinePickerCard extends StatelessWidget {
  const _DeadlinePickerCard({
    required this.deadline,
    required this.onPressed,
    required this.onClear,
  });

  final DateTime? deadline;
  final VoidCallback? onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDeadline = deadline != null;
    final text = hasDeadline
        ? DateFormat('EEE, d MMM yyyy HH:mm').format(deadline!.toLocal())
        : 'Opsional, ketuk untuk mengatur';

    return Card(
      color: hasDeadline
          ? colorScheme.primaryContainer.withValues(alpha: 0.46)
          : Theme.of(context).cardColor,
      child: InkWell(
          borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deadline',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDeadline)
                IconButton(
                  tooltip: 'Hapus deadline',
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassLoadingField extends StatelessWidget {
  const _ClassLoadingField();

  @override
  Widget build(BuildContext context) {
    return const InputDecorator(
      decoration: InputDecoration(
        labelText: 'Kelas',
        prefixIcon: Icon(Icons.groups_outlined),
      ),
      child: LinearProgressIndicator(),
    );
  }
}

class _ClassErrorField extends StatelessWidget {
  const _ClassErrorField({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: 'Coba lagi',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}

class _CreateTaskError extends StatelessWidget {
  const _CreateTaskError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
