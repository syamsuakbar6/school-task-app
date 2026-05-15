import 'package:flutter/material.dart';

class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline,
      backgroundColor: const Color(0xFF1B7F4D),
    );
  }

  static void error(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    _show(
      context,
      message,
      icon: Icons.error_outline,
      backgroundColor: colorScheme.error,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
