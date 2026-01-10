import 'package:dentease/admin/admin_main_layout.dart';
import 'package:dentease/clinic/signup/dental_clinic_signup.dart';
import 'package:dentease/logic/fcm_service.dart';
import 'package:dentease/staff/staff_main_layout.dart';
import 'package:dentease/clinic/resubmission_page.dart';
import 'package:dentease/widgets/background_container.dart';
import 'package:dentease/services/connectivity_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dentease/dentist/dentist_main_layout.dart';
import 'package:dentease/patients/patient_main_layout.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  bool rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false; // Add loading state

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [LoginScreen] Initializing...');
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    debugPrint('💾 [LoginScreen] Loading saved credentials...');
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    final savedRememberMe = prefs.getBool('remember_me') ?? false;

    if (savedRememberMe) {
      debugPrint('💾 [LoginScreen] Found saved credentials for: $savedEmail');
      setState(() {
        emailController.text = savedEmail;
        passwordController.text = savedPassword;
        rememberMe = true;
      });
    } else {
      debugPrint(
          '💾 [LoginScreen] No saved credentials found or rememberMe is false');
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

  /// Show dialog for pending application status
  Future<void> _showPendingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.hourglass_top, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              const Text('Application Pending'),
            ],
          ),
          content: const Text(
            'Your clinic application is currently under review. Please wait for Admin approval before you can access the dashboard.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await supabase.auth.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK, I\'ll Wait'),
            ),
          ],
        );
      },
    );
  }

  /// Login Function
  Future<void> login() async {
    if (_isLoading) return; // Prevent multiple submissions

    // Check internet connectivity first
    try {
      final hasInternet = await ConnectivityService().hasInternetConnection();
      if (!hasInternet) {
        if (mounted) {
          ConnectivityService.showNoInternetDialog(context);
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      // Continue with login attempt if connectivity check fails
    }

    setState(() => _isLoading = true);

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      debugPrint('🔑 [LoginScreen] Attempting login for: $email');

      // Validate input
      if (email.isEmpty || password.isEmpty) {
        debugPrint('⚠️ [LoginScreen] Empty credentials provided');
        _showErrorToast('Please enter both email and password');
        return;
      }

      if (!email.contains('@') || !email.contains('.')) {
        debugPrint('⚠️ [LoginScreen] Invalid email format: $email');
        _showErrorToast('Please enter a valid email address');
        return;
      }

      // Authenticate user
      debugPrint('📡 [LoginScreen] Calling signInWithPassword...');
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) {
        debugPrint('❌ [LoginScreen] Auth response user is null');
        throw 'Login failed';
      }
      debugPrint('✅ [LoginScreen] Auth successful, UID: $userId');

      // Save credentials if Remember Me is checked
      await _saveCredentials(email, password);

      String? userEmail;

      // Check role in `profiles` table
      debugPrint('🔍 [LoginScreen] Checking profiles table for admin role...');
      final profileResponse = await supabase
          .from('profiles')
          .select('role, email')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        final role = profileResponse['role'];
        userEmail = profileResponse['email'];
        debugPrint('👤 [LoginScreen] Found in profiles table. Role: $role');

        if (role == 'admin') {
          debugPrint(
              '👑 [LoginScreen] Admin detected. Initializing admin flow...');
          // Subscribe admin to admin_alerts topic for notifications
          await FCMService.subscribeAdminToTopic();

          if (mounted) {
            _showSuccessToast('Welcome back, Admin!');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminMainLayout()),
            );
          }
          return;
        }
      }

      // Check role in `patients` table
      debugPrint('🔍 [LoginScreen] Checking patients table...');
      final patientResponse = await supabase
          .from('patients')
          .select('role, email')
          .eq('patient_id', userId)
          .maybeSingle();

      if (patientResponse != null) {
        userEmail = patientResponse['email'];
        debugPrint(
            '👤 [LoginScreen] Found in patients table. Email: $userEmail');

        // Save FCM token for patient (with delay to ensure Firebase is ready)
        Future.delayed(const Duration(seconds: 1), () async {
          debugPrint('📡 [LoginScreen] Registering FCM token for patient...');
          try {
            final success = await FCMService.saveUserToken(
              userId: userId,
              tableName: 'patients',
              idColumn: 'patient_id',
            );
            if (!success) {
              debugPrint(
                  '❌ [LoginScreen] Failed to save FCM token for patient: $userId');
            } else {
              debugPrint('✅ [LoginScreen] FCM token saved for patient');
            }
          } catch (e) {
            debugPrint(
                '❌ [LoginScreen] Error saving FCM token for patient: $e');
          }
        });

        if (mounted) {
          _showSuccessToast('Welcome back!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PatientMainLayout()),
          );
        }
        return;
      }

      // Check role in `dentists` table
      debugPrint('🔍 [LoginScreen] Checking dentists table...');
      final dentistResponse = await supabase
          .from('dentists')
          .select('role, email, clinic_id, dentist_id')
          .eq('dentist_id', userId)
          .maybeSingle();

      if (dentistResponse != null) {
        userEmail = dentistResponse['email'];
        final clinicId = dentistResponse['clinic_id']?.toString();
        final dentistId = dentistResponse['dentist_id']?.toString();
        debugPrint(
            '👤 [LoginScreen] Found in dentists table. ClinicID: $clinicId');

        if (clinicId == null || dentistId == null) {
          debugPrint(
              '❌ [LoginScreen] Error: Dentist missing clinicId or dentistId');
          throw 'Your account configuration is incomplete. Please contact support.';
        }

        // Fetch clinic status to determine navigation (force fresh read)
        debugPrint(
            '🔍 [LoginScreen] Fetching fresh clinic status for ID: $clinicId');

        // Use RPC function to get fresh status (bypasses any caching)
        final clinicStatusResult =
            await supabase.rpc('get_clinic_status', params: {
          'p_clinic_id': clinicId,
        });

        if (clinicStatusResult.isEmpty) {
          throw 'Clinic not found';
        }

        final clinicData = clinicStatusResult.first;
        final clinicStatus = clinicData['status'] ?? 'pending';
        final rejectionReason = clinicData['rejection_reason'] ?? '';
        final clinicName = clinicData['clinic_name'] ?? 'Your Clinic';
        final updatedAt = clinicData['updated_at'];

        debugPrint(
            '🏥 [LoginScreen] Clinic: $clinicName Status: $clinicStatus (Updated: $updatedAt)');

        // Route based on clinic status
        if (clinicStatus == 'approved') {
          // Save FCM token for dentist (with delay to ensure Firebase is ready)
          Future.delayed(const Duration(seconds: 1), () async {
            debugPrint('📡 [LoginScreen] Registering FCM token for dentist...');
            try {
              final success = await FCMService.saveUserToken(
                userId: dentistId,
                tableName: 'dentists',
                idColumn: 'dentist_id',
              );
              if (!success) {
                debugPrint(
                    '❌ [LoginScreen] Failed to save FCM token for dentist: $dentistId');
              } else {
                debugPrint('✅ [LoginScreen] FCM token saved for dentist');
              }
            } catch (e) {
              debugPrint(
                  '❌ [LoginScreen] Error saving FCM token for dentist: $e');
            }
          });

          if (mounted) {
            _showSuccessToast('Welcome back!');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DentistMainLayout(clinicId: clinicId, dentistId: dentistId),
              ),
            );
          }
        } else if (clinicStatus == 'pending') {
          debugPrint('⏳ [LoginScreen] Application pending review');
          // Show pending dialog
          await _showPendingDialog();
        } else if (clinicStatus == 'rejected') {
          debugPrint(
              '❌ [LoginScreen] Application rejected. Navigating to resubmission.');
          // Navigate to resubmission page
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ResubmissionPage(
                  clinicId: clinicId,
                  clinicName: clinicName,
                  rejectionReason: rejectionReason,
                  email: userEmail ?? '',
                ),
              ),
            );
          }
        } else {
          debugPrint('⚠️ [LoginScreen] Unknown clinic status: $clinicStatus');
          throw 'Clinic status unknown: $clinicStatus';
        }
        return;
      }

      // Check role in `staffs` table
      debugPrint('🔍 [LoginScreen] Checking staffs table...');
      final staffResponse = await supabase
          .from('staffs')
          .select('role, email, clinic_id, staff_id') // Fetch staff_id
          .eq('staff_id', userId)
          .maybeSingle();

      if (staffResponse != null) {
        userEmail = staffResponse['email'];
        final clinicId = staffResponse['clinic_id']?.toString();
        final staffId = staffResponse['staff_id']?.toString();

        debugPrint(
            '👩‍💼 [LoginScreen] Staff detected: $userEmail (ID: $staffId)');

        if (clinicId == null || staffId == null) {
          debugPrint('❌ [LoginScreen] Staff missing clinicId or staffId');
          throw 'Your staff account is missing clinic information.';
        }

        // Fetch clinic status for staff as well (force fresh read)
        debugPrint(
            '🔍 [LoginScreen] Fetching fresh clinic status for staff clinic: $clinicId');

        // Use RPC function to get fresh status (bypasses any caching)
        final clinicStatusResult =
            await supabase.rpc('get_clinic_status', params: {
          'p_clinic_id': clinicId,
        });

        if (clinicStatusResult.isEmpty) {
          throw 'Clinic not found';
        }

        final clinicData = clinicStatusResult.first;
        final clinicStatus = clinicData['status'] ?? 'pending';
        final clinicName = clinicData['clinic_name'] ?? 'Your Clinic';
        final rejectionReason = clinicData['rejection_reason'] ?? '';
        final updatedAt = clinicData['updated_at'];

        debugPrint(
            '🏥 [LoginScreen] Staff Clinic: $clinicName Status: $clinicStatus (Updated: $updatedAt)');

        if (clinicStatus == 'approved') {
          // Save FCM token for staff (with delay to ensure Firebase is ready)
          Future.delayed(const Duration(seconds: 1), () async {
            debugPrint('📡 [LoginScreen] Registering FCM token for staff...');
            try {
              final success = await FCMService.saveUserToken(
                userId: staffId,
                tableName: 'staffs',
                idColumn: 'staff_id',
              );
              if (!success) {
                debugPrint(
                    '❌ [LoginScreen] Failed to save FCM token for staff: $staffId');
              } else {
                debugPrint(
                    '✅ [LoginScreen] FCM token saved successfully for staff: $staffId');
              }
            } catch (e) {
              debugPrint(
                  '❌ [LoginScreen] Error saving FCM token for staff: $e');
            }
          });

          if (mounted) {
            _showSuccessToast('Welcome back!');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    StaffMainLayout(clinicId: clinicId, staffId: staffId),
              ),
            );
          }
        } else if (clinicStatus == 'rejected') {
          debugPrint('❌ [LoginScreen] Staff clinic rejected.');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ResubmissionPage(
                  clinicId: clinicId,
                  clinicName: clinicName,
                  rejectionReason: rejectionReason,
                  email: userEmail ?? '',
                ),
              ),
            );
          }
        } else {
          debugPrint('⏳ [LoginScreen] Staff clinic $clinicStatus');
          await _showPendingDialog();
        }
        return;
      }

      // If no role found in any table, provide detailed error
      debugPrint('Login failed - User ID: $userId, Email: $email');
      debugPrint(
          'User exists in auth but not found in any role table (profiles, patients, dentists, staffs)');

      throw 'Account not found or not properly configured. Please contact support.';
    } on AuthException catch (e) {
      if (mounted) {
        if (e.message.toLowerCase().contains('invalid') ||
            e.message.toLowerCase().contains('email') ||
            e.message.toLowerCase().contains('password')) {
          _showErrorToast('Invalid email or password. Please try again.');
        } else if (e.message.toLowerCase().contains('network')) {
          _showErrorToast('Network error. Please check your connection.');
        } else {
          _showErrorToast('Login failed: ${e.message}');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [LoginScreen] Unexpected error during login: $e');
      debugPrint('📚 [LoginScreen] Stack Trace: $stackTrace');
      if (mounted) {
        _showErrorToast('Login failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
                    prefixIcon: Icon(Icons.mail, color: AppTheme.primaryBlue),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword, // use the toggle
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: AppTheme.primaryBlue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.primaryBlue,
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
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isLoading ? Colors.grey[400] : Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    minimumSize: const Size(400, 20),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryBlue),
                          ),
                        )
                      : Text(
                          'Login',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue),
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
                            color: AppTheme.primaryBlue,
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
                      color: AppTheme.primaryBlue,
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
