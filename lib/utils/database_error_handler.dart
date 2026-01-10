import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseErrorHandler {
  static String getReadableError(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '42P01':
          return 'Database table not found. Please contact support.';
        case '42703':
          return 'Database column not found. Please update the app.';
        case '23505':
          return 'This record already exists.';
        case '23503':
          return 'Cannot delete this record as it is referenced by other data.';
        case '42501':
          return 'You do not have permission to perform this action.';
        default:
          return 'Database error: ${error.message}';
      }
    }

    if (error.toString().contains('Lost connection')) {
      return 'Connection lost. Please check your internet connection and try again.';
    }

    if (error.toString().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return 'An unexpected error occurred: ${error.toString()}';
  }

  static bool isRetryableError(dynamic error) {
    if (error is PostgrestException) {
      // Don't retry structural errors
      if (['42P01', '42703', '42501'].contains(error.code)) {
        return false;
      }
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('network');
  }

  static void logError(String context, dynamic error,
      [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('❌ [$context] Error: $error');
      if (stackTrace != null) {
        print('📚 [$context] Stack trace: $stackTrace');
      }
    }
  }

  static Future<T?> executeWithRetry<T>(
    Future<T> Function() operation,
    String context, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        attempts++;
        logError(context, error, stackTrace);

        if (attempts >= maxRetries || !isRetryableError(error)) {
          rethrow;
        }

        if (kDebugMode) {
          print(
              '🔄 [$context] Retrying in ${delay.inSeconds}s (attempt $attempts/$maxRetries)');
        }

        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2); // Exponential backoff
      }
    }

    return null;
  }
}
