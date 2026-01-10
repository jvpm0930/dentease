import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to handle internet connectivity checks
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Stream controller for connectivity changes
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  /// Stream of connectivity status (true = connected, false = disconnected)
  Stream<bool> get connectivityStream => _connectivityController.stream;

  bool _isConnected = true;

  /// Get current connectivity status
  bool get isConnected => _isConnected;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      await _updateConnectivityStatus();

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _handleConnectivityChange(results);
        },
        onError: (error) {
          debugPrint('Connectivity stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error initializing connectivity service: $e');
      // Set default connected state if initialization fails
      _isConnected = true;
      _connectivityController.add(true);
    }
  }

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final List<ConnectivityResult> connectivityResults =
          await _connectivity.checkConnectivity();
      return _hasConnection(connectivityResults);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Update connectivity status
  Future<void> _updateConnectivityStatus() async {
    final bool connected = await hasInternetConnection();
    _isConnected = connected;
    _connectivityController.add(connected);
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final bool connected = _hasConnection(results);
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectivityController.add(connected);
      debugPrint(
          'Connectivity changed: ${connected ? 'Connected' : 'Disconnected'}');
    }
  }

  /// Check if connectivity results indicate a connection
  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);
  }

  /// Show no internet dialog
  static Future<void> showNoInternetDialog(context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('No Internet Connection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please check your internet connection and try again.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Troubleshooting:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Check WiFi or mobile data'),
                  const Text('• Try turning airplane mode on/off'),
                  const Text('• Restart your device if needed'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Check connectivity again
              final hasConnection =
                  await ConnectivityService().hasInternetConnection();
              if (!hasConnection) {
                // Show dialog again if still no connection
                Future.delayed(const Duration(milliseconds: 500), () {
                  showNoInternetDialog(context);
                });
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}
