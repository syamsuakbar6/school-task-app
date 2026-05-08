import 'package:flutter/material.dart';

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !isLoading;
    final borderRadius = BorderRadius.circular(12);
    final gradient = LinearGradient(
      colors: [
        colorScheme.primary,
        Color.lerp(colorScheme.primary, Colors.black, 0.18)!,
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: enabled ? gradient : null,
        color: enabled ? null : colorScheme.surfaceContainer,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              size: 20,
                              color: enabled
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: enabled
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
}
