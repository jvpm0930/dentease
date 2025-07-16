import 'package:dentease/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://qotjgevjzmnqvmgaarod.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvdGpnZXZqem1ucXZtZ2Fhcm9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgyMjQ1MTIsImV4cCI6MjA1MzgwMDUxMn0.WkopnvxlUQglBI-lrWbFw6mNas2FhuxXdxrn2iiUO-U',
  );

  runApp(MyApp());
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
          fillColor: Colors.grey[300], // Light grey background
          hintStyle: TextStyle(color: Colors.indigoAccent[900]), 
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30), // Rounded corners
            borderSide: BorderSide.none, // No border
          ),
          contentPadding: EdgeInsets.symmetric(
              vertical: 15, horizontal: 20), // Adjust padding
        ),
      ),
      home: LoginScreen(), // Start with SplashScreen
    );
  }
}
