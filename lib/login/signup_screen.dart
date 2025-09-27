import 'package:dentease/widgets/background_container.dart';
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
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'patient'; // Default role
  bool _obscurePassword = true;

  final supabase = Supabase.instance.client;

  /// ** Check if Email Already Exists**
  Future<bool> _checkIfEmailExists(String email) async {
    final response = await supabase
        .from('patients')
        .select('patient_id')
        .eq('email', email)
        .maybeSingle();

    return response != null; // If response is not null, email exists
  }

  /// ** Sign-Up Function with Duplicate Checks**
  Future<void> signUp() async {
    try {
      final firstname = firstnameController.text.trim();
      final lastname = lastnameController.text.trim();
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      //  **Check for Empty Fields**
      if (firstname.isEmpty ||
          lastname.isEmpty ||
          phone.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        _showSnackbar('Please fill in all fields.');
        return;
      }

      //  **Check if Email Exists**
      if (await _checkIfEmailExists(email)) {
        _showSnackbar('Email already exists. Please use another email.');
        return;
      }

      //  **Create User in Supabase Auth**
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw 'User creation failed';

      //  **Store Additional User Info in Profiles Table**
      await supabase.from('patients').insert({
        'patient_id': userId,
        'firstname': firstname,
        'lastname': lastname,
        'phone': phone,
        'email': email,
        'password': password,
        'role': selectedRole, // Store selected role
      });

      //  **Success Message & Navigate to Login**
      _showSnackbar('Signup successful! Please login.');
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => LoginScreen()));
    } catch (e) {
      _showSnackbar('Error: $e');
    }
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
                    _buildTextField(
                        phoneController, 'Phone Number', Icons.phone),
                    SizedBox(height: 10),
                    _buildTextField(emailController, 'Email', Icons.mail,
                        keyboardType: TextInputType.emailAddress),
                    SizedBox(height: 10),
                    _buildTextField(passwordController, 'Password', Icons.lock,
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
          child: Icon(icon, color: Colors.indigo[900]),
        ),
        // Only show eye toggle for password fields
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.indigo[900],
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
        onPressed: signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300], // Light grey background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50), // Fully rounded edges
          ),
          padding: EdgeInsets.symmetric(vertical: 13),
          minimumSize: Size(400, 20), // Wider button
          elevation: 0, // No shadow
        ),
        child: Text(
          'Sign Up',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[900], // Dark blue text
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
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
