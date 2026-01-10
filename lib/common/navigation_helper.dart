import 'package:flutter/material.dart';

/// Safe navigation helper to prevent duplicate page stacking
/// Uses pushReplacement to replace current page instead of stacking
void safeNavigate(BuildContext context, Widget page) {
  if (!context.mounted) return;
  
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => page),
  );
}

/// Safe push navigation (for when you want to add to stack)
/// Includes mounted check for safety
void safePush(BuildContext context, Widget page) {
  if (!context.mounted) return;
  
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => page),
  );
}
