import 'package:flutter/material.dart';

/// A safe navigation utility that prevents duplicate page pushes
/// when users tap buttons rapidly.
class SafeNavigator {
  static DateTime _lastNavigationTime = DateTime.now();
  static const Duration _navigationCooldown = Duration(milliseconds: 300);

  /// Check if enough time has passed since the last navigation
  static bool _canNavigate() {
    final now = DateTime.now();
    if (now.difference(_lastNavigationTime) > _navigationCooldown) {
      _lastNavigationTime = now;
      return true;
    }
    return false;
  }

  /// Safe push - prevents duplicate pushes
  static Future<T?> push<T>(BuildContext context, Widget page) async {
    if (!_canNavigate()) return null;
    
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// Safe pushReplacement - prevents duplicate pushes
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) async {
    if (!_canNavigate()) return null;
    
    return Navigator.pushReplacement<T, TO>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// Safe pushAndRemoveUntil - prevents duplicate pushes
  static Future<T?> pushAndRemoveUntil<T>(
    BuildContext context,
    Widget page,
    RoutePredicate predicate,
  ) async {
    if (!_canNavigate()) return null;
    
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute(builder: (_) => page),
      predicate,
    );
  }

  /// Reset navigation lock (useful for testing)
  static void reset() {
    _lastNavigationTime = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
