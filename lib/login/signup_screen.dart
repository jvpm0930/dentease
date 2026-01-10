import 'package:dentease/widgets/background_container.dart';
import 'package:dentease/services/connectivity_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final firstnameController = TextEditingController();
  final lastnameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'patient'; // Default role
  bool _obscurePassword = true;
  bool _isLoading = false; // Add loading state

  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  /// ** Check if Email Already Exists**
  Future<bool> _checkIfEmailExists(String email) async {
    debugPrint('📡 [PatientSignup] Checking if email exists: $email');

    // Check both patients table and auth users
    try {
      final response = await supabase
          .from('patients')
          .select('patient_id')
          .eq('email', email)
          .maybeSingle();

      final exists = response != null;
      debugPrint('📊 [PatientSignup] Email exists in patients: $exists');
      return exists;
    } catch (e) {
      debugPrint('⚠️ [PatientSignup] Error checking email: $e');
      return false;
    }
  }

  Future<void> signUp() async {
    if (_isLoading) return; // Prevent multiple submissions

    // Check internet connectivity first
    final hasInternet = await ConnectivityService().hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ConnectivityService.showNoInternetDialog(context);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firstname = firstnameController.text.trim();
      final lastname = lastnameController.text.trim();
      final age = ageController.text
          .trim(); // FIXED: you had emailController here before
      final gender = genderController.text.trim(); // FIXED same issue
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      debugPrint('📝 [PatientSignup] Starting signup for: $email');

      //  **Check for Empty Fields**
      if (firstname.isEmpty ||
          lastname.isEmpty ||
          age.isEmpty ||
          gender.isEmpty ||
          phone.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        debugPrint('⚠️ [PatientSignup] Empty fields detected');
        _showErrorToast('Please fill in all fields.');
        return;
      }

      // **Validate email format**
      if (!email.contains('@') || !email.contains('.')) {
        debugPrint('⚠️ [PatientSignup] Invalid email format: $email');
        _showErrorToast('Please enter a valid email address.');
        return;
      }

      // **Validate password length**
      if (password.length < 6) {
        debugPrint('⚠️ [PatientSignup] Password too short');
        _showErrorToast('Password must be at least 6 characters long.');
        return;
      }

      // **Validate age**
      final ageInt = int.tryParse(age);
      if (ageInt == null || ageInt < 1 || ageInt > 120) {
        debugPrint('⚠️ [PatientSignup] Invalid age: $age');
        _showErrorToast('Please enter a valid age between 1 and 120.');
        return;
      }

      //  **Check if Email Exists**
      if (await _checkIfEmailExists(email)) {
        _showErrorToast('Email already exists. Please use another email.');
        return;
      }

      // **Sign Up with Email Verification**
      debugPrint('📡 [PatientSignup] Calling auth.signUp...');
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      // Check if user creation was successful
      if (authResponse.user == null) {
        debugPrint('❌ [PatientSignup] Auth signup failed - no user returned');
        _showErrorToast('Account creation failed. Please try again.');
        return;
      }

      final userId = authResponse.user!.id;
      debugPrint('✅ [PatientSignup] Auth successful, UID: $userId');

      //  **Insert user data into patients table**
      debugPrint('📡 [PatientSignup] Inserting data into patients table...');
      await supabase.from('patients').insert({
        'patient_id': userId,
        'id': userId, // Also set id field for compatibility
        'firstname': firstname,
        'lastname': lastname,
        'age': ageInt, // Use parsed integer
        'gender': gender,
        'phone': phone,
        'email': email,
        'password': password,
        'role': selectedRole,
      });
      debugPrint('✅ [PatientSignup] Information saved to patients table');

      if (mounted) {
        _showSuccessToast('Account created successfully! Please login.');
        // **Redirect to Login**
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } on AuthException catch (e) {
      debugPrint('❌ [PatientSignup] AuthException: ${e.message}');
      if (mounted) {
        if (e.message.toLowerCase().contains('user_already_registered') ||
            e.message.toLowerCase().contains('already registered')) {
          _showErrorToast(
              'Email already registered. Please use a different email or try logging in.');
        } else if (e.message.toLowerCase().contains('email')) {
          _showErrorToast('Invalid email format or email already in use.');
        } else if (e.message.toLowerCase().contains('password')) {
          _showErrorToast(
              'Password is too weak. Please use a stronger password.');
        } else {
          _showErrorToast('Signup failed: ${e.message}');
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ [PatientSignup] PostgrestException: ${e.message}');
      if (mounted) {
        if (e.message.toLowerCase().contains('duplicate') ||
            e.message.toLowerCase().contains('unique')) {
          _showErrorToast(
              'Email already exists. Please use a different email.');
        } else {
          _showErrorToast('Database error: ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('❌ [PatientSignup] General Exception: $e');
      if (mounted) {
        _showErrorToast('Signup failed. Please try again.');
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

  /// ** Snackbar Message Helper**
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
        child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(height: 30), // App Logo
                    Text(
                      'Patient Signup',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildTextField(
                        firstnameController, 'Firstname', Icons.person),
                    SizedBox(height: 10),
                    _buildTextField(
                        lastnameController, 'Lastname', Icons.person),
                    SizedBox(height: 10),
                    // AGE - styled same as other textfields
                    _buildTextField(
                      ageController,
                      'Age',
                      Icons.calculate,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: genderController.text.isNotEmpty
                          ? genderController.text
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Gender',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.wc_rounded,
                              color: AppTheme.primaryBlue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
                        // Rounded corners
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                        DropdownMenuItem(
                            value: 'Not Specify', child: Text('Not Specify')),
                      ],
                      onChanged: (value) {
                        genderController.text = value!;
                      },
                    ),
                    SizedBox(height: 10),
                    _buildTextField(
                        phoneController, 'Phone Number', Icons.phone),
                    SizedBox(height: 10),
                    _buildTextField(emailController, 'Email', Icons.mail,
                        keyboardType: TextInputType.emailAddress),
                    SizedBox(height: 10),
                    _buildTextField(passwordController,
                        'Password (minimum of 6 digits)', Icons.lock,
                        isPassword: true),
                    SizedBox(height: 20),
                    _buildSignUpButton(),
                    _buildLoginTextButton(),
                  ],
                ),
              ),
            )));
  }

  /// ** Reusable TextField Widget**
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        // Only show eye toggle for password fields
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
      ),
    );
  }

  /// ** Sign-Up Button Widget**
  Widget _buildSignUpButton() {
    return ElevatedButton(
        onPressed: _isLoading ? null : signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoading
              ? Colors.grey[400]
              : Colors.grey[300], // Light grey background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50), // Fully rounded edges
          ),
          padding: EdgeInsets.symmetric(vertical: 13),
          minimumSize: Size(400, 20), // Wider button
          elevation: 0, // No shadow
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                ),
              )
            : Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ));
  }

  /// ** Login Redirect Button**
  Widget _buildLoginTextButton() {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      ),
      child: const Text.rich(
        TextSpan(
          text: "Already have a Patient Account? ",
          style: TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: "Login",
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
