import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/auth_session.dart';
import '../services/notification_service.dart';
import '../widgets/gradient_action_button.dart';

class SubmitTaskScreen extends StatefulWidget {
  const SubmitTaskScreen({
    super.key,
    required this.session,
    required this.task,
  });

  final AuthSession session;
  final Task task;

  @override
  State<SubmitTaskScreen> createState() => _SubmitTaskScreenState();
}

class _SubmitTaskScreenState extends State<SubmitTaskScreen> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'docx',
        'png',
        'jpg',
        'jpeg',
        'txt',
        'zip',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedFile = result.files.single;
      _errorMessage = null;
    });
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null) {
      setState(() => _errorMessage = 'Pilih file terlebih dahulu.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await widget.session.api.submitTask(
        taskId: widget.task.id,
        file: file,
      );

      if (!mounted) return;

      await NotificationService.showSubmitSuccess(widget.task.title);

      await _showSuccessDialog();

    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 48,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tugas Berhasil Dikirim!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"${widget.task.title}" sudah terkirim.\nTunggu penilaian dari guru ya!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 46),
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Oke, Siap!'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kumpulkan Tugas',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.primary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            widget.task.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          _FileDropzone(
            file: _selectedFile,
            onTap: _isUploading ? null : _pickFile,
          ),
          const SizedBox(height: 24),
          GradientActionButton(
            label: _isUploading ? 'Mengirim...' : 'Kirim Tugas',
            icon: Icons.cloud_upload_outlined,
            onPressed: _isUploading ? null : _upload,
            isLoading: _isUploading,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _StatusMessage(message: _errorMessage!),
          ],
        ],
      ),
    );
  }
}

// ── File Dropzone ─────────────────────────────────────────────────────────────

class _FileDropzone extends StatelessWidget {
  const _FileDropzone({
    required this.file,
    required this.onTap,
  });

  final PlatformFile? file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasFile = file != null;

    return Card(
      color: hasFile
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: hasFile
                ? colorScheme.primary.withValues(alpha: 0.42)
                : colorScheme.outlineVariant,
            radius: 8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Center(
              child: hasFile
                  ? Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 34,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatBytes(file!.size),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 42,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ketuk untuk pilih file',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PDF, DOCX, PNG, JPG, TXT, ZIP',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 8.0;
      const dashSpace = 5.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        final end = next.clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

// ── Status Message ────────────────────────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
