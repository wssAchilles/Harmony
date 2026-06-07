import 'package:flutter/material.dart';

import '../motion/motion.dart';

enum AsyncActionState { idle, loading, success, error }

class AsyncActionButton extends StatelessWidget {
  const AsyncActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.state = AsyncActionState.idle,
    this.successLabel = '完成',
    this.errorLabel = '重试',
    this.icon,
    this.successIcon = Icons.check,
    this.errorIcon = Icons.error_outline,
    this.minimumHeight = 48,
  });

  final VoidCallback? onPressed;
  final String label;
  final AsyncActionState state;
  final String successLabel;
  final String errorLabel;
  final IconData? icon;
  final IconData successIcon;
  final IconData errorIcon;
  final double minimumHeight;

  bool get _isBusy => state == AsyncActionState.loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: minimumHeight,
      child: ElevatedButton(
        onPressed: _isBusy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (state) {
      case AsyncActionState.loading:
        return const SizedBox(
          key: ValueKey('loading'),
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case AsyncActionState.success:
        return _ButtonContent(
          key: const ValueKey('success'),
          icon: successIcon,
          label: successLabel,
        );
      case AsyncActionState.error:
        return _ButtonContent(
          key: const ValueKey('error'),
          icon: errorIcon,
          label: errorLabel,
        );
      case AsyncActionState.idle:
        return _ButtonContent(
          key: const ValueKey('idle'),
          icon: icon,
          label: label,
        );
    }
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
