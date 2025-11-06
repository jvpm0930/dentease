import 'dart:io'; //  Needed for Platform.isAndroid
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login/login_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //  Initialize local notifications
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  //  Request permission (Android 13+ requires this)
  if (Platform.isAndroid) {
    // No explicit permission needed for older Android versions
    print("Android notification permission handled automatically.");
  }


  //  Initialize Supabase
  await Supabase.initialize(
    url: 'https://qotjgevjzmnqvmgaarod.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvdGpnZXZqem1ucXZtZ2Fhcm9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgyMjQ1MTIsImV4cCI6MjA1MzgwMDUxMn0.WkopnvxlUQglBI-lrWbFw6mNas2FhuxXdxrn2iiUO-U',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[300],
          hintStyle: TextStyle(color: Colors.indigo[900]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
