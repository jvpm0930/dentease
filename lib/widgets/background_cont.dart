import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BackgroundCont extends StatelessWidget {
  final Widget child;

  const BackgroundCont({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: child,
    );
  }
}
