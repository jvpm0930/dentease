import 'package:dentease/admin/pages/clinics/admin_dentease_first.dart';
import 'package:dentease/clinic/signup/dental_clinic_signup.dart';
import 'package:dentease/staff/staff_page.dart';
import 'package:dentease/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dentist/dentist_page.dart';
import '../patients/patient_pagev2.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    final savedRememberMe = prefs.getBool('remember_me') ?? false;

    if (savedRememberMe) {
      setState(() {
        emailController.text = savedEmail;
        passwordController.text = savedPassword;
        rememberMe = true;
      });
    }
  }

  /// Save credentials if "Remember Me" is checked
  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  /// Login Function
  Future<void> login() async {
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // Authenticate user
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) throw 'Login failed';

      // Save credentials if Remember Me is checked
      await _saveCredentials(email, password);

      String? userEmail;

      // Check role in `profiles` table
      final profileResponse = await supabase
          .from('profiles')
          .select('role, email')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        final role = profileResponse['role'];
        userEmail = profileResponse['email'];

        if (role == 'admin') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logged in as $userEmail')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AdminPage()),
          );
          return;
        }
      }

      // Check role in `patients` table
      final patientResponse = await supabase
          .from('patients')
          .select('role, email')
          .eq('patient_id', userId)
          .maybeSingle();

      if (patientResponse != null) {
        userEmail = patientResponse['email'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in as $userEmail')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PatientPage()),
        );
        return;
      }

      // Check role in `dentists` table
      final dentistResponse = await supabase
          .from('dentists')
          .select('role, email, clinic_id, dentist_id')
          .eq('dentist_id', userId)
          .maybeSingle();

      if (dentistResponse != null) {
        userEmail = dentistResponse['email'];
        String clinicId = dentistResponse['clinic_id']; // Get clinic_id
        String dentistId = dentistResponse['dentist_id']; // Get staff_id

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in as $userEmail')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DentistPage(clinicId: clinicId, dentistId: dentistId),
          ),
        );
        return;
      }

      // Check role in `staffs` table
      final staffResponse = await supabase
          .from('staffs')
          .select('role, email, clinic_id, staff_id') // Fetch staff_id
          .eq('staff_id', userId)
          .maybeSingle();

      if (staffResponse != null) {
        userEmail = staffResponse['email'];
        String clinicId = staffResponse['clinic_id']; // Get clinic_id
        String staffId = staffResponse['staff_id']; // Get staff_id

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in as $userEmail')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StaffPage(clinicId: clinicId, staffId: staffId),
          ),
        );
        return;
      }

      throw 'User role not found in any table';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Try Again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 30),
                Image.asset('assets/logo2.png', width: 500),
                const SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: Icon(Icons.mail, color: const Color(0xFF103D7E)),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword, // use the toggle
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: const Color(0xFF103D7E)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF103D7E),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      onChanged: (value) {
                        setState(() {
                          rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text('Remember Me',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    minimumSize: const Size(400, 20),
                    elevation: 0,
                  ),
                  child: Text(
                    'Login',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF103D7E)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      text: "Don't have an Account? ",
                      style: TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: "Sign up",
                          style: TextStyle(
                            color: Color(0xFF103D7E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                 const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DentalApplyFirst()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    minimumSize: const Size(400, 20),
                    elevation: 0,
                  ),
                  child: Text(
                    'Be our Partner',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF103D7E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}