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
  final _classIdController = TextEditingController(text: '1');

  DateTime? _deadline;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _classIdController.dispose();
    super.dispose();
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

    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.session.api.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        deadline: _deadline,
        classId: int.parse(_classIdController.text.trim()),
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
          'Create Task',
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
                labelText: 'Title',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _classIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Class ID',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              validator: (value) {
                final id = int.tryParse((value ?? '').trim());
                if (id == null || id < 1) return 'Enter a valid class ID';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _DeadlinePickerCard(
              deadline: _deadline,
              onPressed: _isSaving ? null : _pickDeadline,
            ),
            const SizedBox(height: 24),
            GradientActionButton(
              label: 'Create task',
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
  });

  final DateTime? deadline;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDeadline = deadline != null;
    final text = hasDeadline
        ? DateFormat('EEE, d MMM yyyy HH:mm').format(deadline!.toLocal())
        : 'Tap to set deadline';

    return Card(
      color: hasDeadline
          ? colorScheme.primaryContainer.withValues(alpha: 0.46)
          : Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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
