import 'package:dentease/login/login_screen.dart';
import 'package:dentease/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentAddPatient extends StatefulWidget {
  final String clinicId;

  const DentAddPatient({super.key, required this.clinicId});

  @override
  _DentAddPatientState createState() => _DentAddPatientState();
}

class _DentAddPatientState extends State<DentAddPatient> {
  final supabase = Supabase.instance.client;

  final firstnameController = TextEditingController();
  final lastnameController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> signUp() async {
    try {
      final firstname = firstnameController.text.trim();
      final lastname = lastnameController.text.trim();
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (firstname.isEmpty ||
          lastname.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        _showSnackbar('Please fill in all required fields.');
        return;
      }

      if (!RegExp(r"^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$").hasMatch(email)) {
        _showSnackbar('Please enter a valid email.');
        return;
      }

      if (password.length < 6) {
        _showSnackbar('Password must be at least 6 characters long.');
        return;
      }

      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        _showSnackbar('Sign-up failed. Please check your details.');
        return;
      }

      await supabase.from('patients').insert({
        'staff_id': user.id,
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'phone': phone,
        'role': 'patient',
      });

      _showSnackbar('Login to Verify');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } catch (e) {
      _showSnackbar('Error: $e');
    }
  }

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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Image.asset('assets/logo2.png', width: 500),
                const Text('Add Patient', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                _buildTextField(emailController, 'Email', Icons.mail),
                const SizedBox(height: 10),
                _buildTextField(passwordController, 'Password', Icons.lock,
                    isPassword: true),
                const SizedBox(height: 10),
                _buildTextField(firstnameController, 'Firstname', Icons.person),
                const SizedBox(height: 10),
                _buildTextField(lastnameController, 'Lastname', Icons.person),
                const SizedBox(height: 10),
                _buildTextField(phoneController, 'Phone Number', Icons.phone),
                const SizedBox(height: 20),
                _buildSignUpButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon, color: Colors.indigo[900]),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: signUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        minimumSize: const Size(400, 20),
        elevation: 0,
      ),
      child: Text(
        'Add Staff',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[900], // Fixed this line
        ),
      ),
    );
  }
}
