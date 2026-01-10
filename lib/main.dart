import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';
import 'login/login_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'logic/fcm_service.dart';
import 'theme/app_theme.dart';
import 'services/connectivity_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Global flag to track if Supabase has been initialized
bool isSupabaseInitialized = false;

//  Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Force portrait mode for the entire app
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Run the app immediately with initialization happening inside
  runApp(const SafeApp());
}

/// A wrapper app that handles initialization safely
/// This ensures the app starts immediately and shows a loading screen
/// while all services are being initialized in the background
class SafeApp extends StatefulWidget {
  const SafeApp({super.key});

  @override
  State<SafeApp> createState() => _SafeAppState();
}

class _SafeAppState extends State<SafeApp> {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize Firebase first
      await Firebase.initializeApp();

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Initialize FCM Service
      await FCMService.initialize();

      // Initialize Connectivity Service (with error handling)
      try {
        await ConnectivityService().initialize();
      } catch (e) {
        debugPrint('Failed to initialize connectivity service: $e');
        // Continue without connectivity service if it fails
      }

      // Initialize local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await flutterLocalNotificationsPlugin.initialize(initSettings);

      // Request permission (Android 13+ requires this)
      if (Platform.isAndroid) {
        debugPrint("Android notification permission handled automatically.");
      }

      // Initialize Supabase - THIS IS CRITICAL
      await Supabase.initialize(
        url: 'https://qotjgevjzmnqvmgaarod.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvdGpnZXZqem1ucXZtZ2Fhcm9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgyMjQ1MTIsImV4cCI6MjA1MzgwMDUxMn0.WkopnvxlUQglBI-lrWbFw6mNas2FhuxXdxrn2iiUO-U',
      );

      // Mark Supabase as initialized
      isSupabaseInitialized = true;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while initializing
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          backgroundColor: AppTheme.primaryBlue,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo2.png', width: 200),
                const SizedBox(height: 30),
                if (_initError != null) ...[
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Failed to initialize app.\nPlease check your internet connection and try again.',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initError = null;
                      });
                      _initializeApp();
                    },
                    child: const Text('Retry'),
                  ),
                ] else ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Initializing...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Once initialized, show the main app
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Named routes for navigation
      routes: {
        '/login': (context) => const LoginScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
