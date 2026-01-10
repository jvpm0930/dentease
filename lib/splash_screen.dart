import 'package:dentease/admin/admin_main_layout.dart';
import 'package:dentease/dentist/dentist_main_layout.dart';
import 'package:dentease/login/login_screen.dart';
import 'package:dentease/logic/fcm_service.dart';
import 'package:dentease/patients/patient_main_layout.dart';
import 'package:dentease/staff/staff_main_layout.dart';
import 'package:dentease/services/connectivity_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Use a getter instead of field initializer to avoid race condition
  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Check internet connectivity first
    final hasInternet = await ConnectivityService().hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ConnectivityService.showNoInternetDialog(context);
      }
      return;
    }

    // 🔧 FIX: Add timeout to prevent "stuck on loading"
    try {
      await Future.delayed(Duration.zero); // Ensure async context

      // Start a timer to force login if things take too long (25 seconds max)
      // This protects against hanging database queries
      final result = await Future.any([
        _performChecks().then((_) => 'success'),
        Future.delayed(const Duration(seconds: 25), () => 'timeout'),
      ]);

      if (result == 'timeout') {
        debugPrint("⚠️ Session check timed out");
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
      _navigateToLogin();
    }
  }

  Future<void> _performChecks() async {
    // Check if there's an existing session
    debugPrint('🚀 [Splash] Checking session...');
    final session = supabase.auth.currentSession;

    if (session == null || session.user == null) {
      debugPrint('🚀 [Splash] No active session found. Redirecting to login.');
      _navigateToLogin();
      return;
    }

    final userId = session.user!.id;
    debugPrint('🚀 [Splash] Found active session for user: $userId');

    // 1. Check Admin Profile
    debugPrint('🔍 [Splash] Checking profiles table for admin role...');
    final profileResponse = await supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10)); // Individual timeout

    if (profileResponse != null && profileResponse['role'] == 'admin') {
      debugPrint('👑 [Splash] Admin detected.');
      await FCMService.subscribeAdminToTopic();
      _navigateToAdminDashboard();
      return;
    }

    // 2. Check Patients
    debugPrint('🔍 [Splash] Checking patients table...');
    final patientResponse = await supabase
        .from('patients')
        .select('patient_id')
        .eq('patient_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (patientResponse != null) {
      debugPrint('👤 [Splash] Patient detected.');
      _navigateToPatientDashboard();
      return;
    }

    // 3. Check Dentists
    debugPrint('🔍 [Splash] Checking dentists table...');
    final dentistResponse = await supabase
        .from('dentists')
        .select('clinic_id, dentist_id')
        .eq('dentist_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (dentistResponse != null) {
      final clinicId = dentistResponse['clinic_id'].toString();
      final dentistId = dentistResponse['dentist_id'].toString();
      debugPrint('🩺 [Splash] Dentist detected. Clinic: $clinicId');

      debugPrint('🔍 [Splash] Verifying clinic status...');
      final clinicResponse = await supabase
          .from('clinics')
          .select('status')
          .eq('clinic_id', clinicId)
          .maybeSingle();

      final clinicStatus = clinicResponse?['status'] ?? 'pending';
      debugPrint('🏥 [Splash] Clinic status: $clinicStatus');

      if (clinicStatus == 'approved') {
        _navigateToDentistDashboard(clinicId, dentistId);
      } else {
        debugPrint('⏳ [Splash] Clinic not approved. Redirecting to login.');
        await supabase.auth.signOut();
        _navigateToLogin();
      }
      return;
    }

    // 4. Check Staff
    debugPrint('🔍 [Splash] Checking staffs table...');
    final staffResponse = await supabase
        .from('staffs')
        .select('clinic_id, staff_id')
        .eq('staff_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (staffResponse != null) {
      final clinicId = staffResponse['clinic_id'].toString();
      final staffId = staffResponse['staff_id'].toString();
      debugPrint('👩‍💼 [Splash] Staff detected. Clinic: $clinicId');
      _navigateToStaffDashboard(clinicId, staffId);
      return;
    }

    // User not found anywhere
    debugPrint(
        '⚠️ [Splash] User found in Auth but not in any role table. Signing out...');
    await supabase.auth.signOut();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigateToAdminDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminMainLayout()),
    );
  }

  void _navigateToPatientDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PatientMainLayout()),
    );
  }

  void _navigateToDentistDashboard(String clinicId, String dentistId) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DentistMainLayout(clinicId: clinicId, dentistId: dentistId),
      ),
    );
  }

  void _navigateToStaffDashboard(String clinicId, String staffId) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StaffMainLayout(clinicId: clinicId, staffId: staffId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo2.png', width: 200),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
