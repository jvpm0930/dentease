import 'package:dentease/clinic/signup/dental_clinic_apply.dart';
import 'package:dentease/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentalSignup extends StatefulWidget {
  final String clinicId;
  final String email;

  const DentalSignup({
    super.key,
    required this.clinicId,
    required this.email,
  });

  @override
  _DentalSignupState createState() => _DentalSignupState();
}

class _DentalSignupState extends State<DentalSignup> {
  final firstnameController = TextEditingController();
  final lastnameController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  late TextEditingController emailController;
  late TextEditingController clinicController;
  String selectedRole = 'dentist'; // Default role
  bool _obscurePassword = true;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with passed values
    clinicController = TextEditingController(text: widget.clinicId);
    emailController = TextEditingController(text: widget.email);
  }

  /// * Check if Email Already Exists**
  Future<bool> _checkIfEmailExists(String email) async {
    final response = await supabase
        .from('dentists')
        .select('dentist_id')
        .eq('email', email)
        .maybeSingle();

    return response != null; // If response is not null, email exists
  }

  /// **Check if Firstname & Lastname Already Exist**
  Future<bool> _checkIfNameExists(String firstname, String lastname) async {
    final response = await supabase
        .from('dentists')
        .select('dentist_id')
        .eq('firstname', firstname)
        .eq('lastname', lastname)
        .maybeSingle();

    return response != null; // If response is not null, name exists
  }

  /// ** Sign-Up Function with Duplicate Checks**
  Future<void> signUp() async {
    try {
      final firstname = firstnameController.text.trim();
      final lastname = lastnameController.text.trim();
      final password = passwordController.text.trim();
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();
      final clinicId = clinicController.text.trim();

      // **Check for Empty Fields**
      if (firstname.isEmpty || lastname.isEmpty || password.isEmpty) {
        _showSnackbar('Please fill in all fields.');
        return;
      }

      // **Check if First & Last Name Exists**
      if (await _checkIfNameExists(firstname, lastname)) {
        _showSnackbar('Name already taken. Please use a different name.');
        return;
      }

      // **Create User in Supabase Auth**
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw 'User creation failed';

      // **Store Additional User Info in dentists Table**
      await supabase.from('dentists').insert({
        'dentist_id': userId,
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'password': password,
        'phone': phone,
        'clinic_id': clinicId, // Store clinic ID
        'role': selectedRole, // Store selected role
      });

      // **Success Message & Navigate to Login Page**
      _showSnackbar('Signup successful! Next More Details');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DentistApplyPage(
            clinicId: clinicId, // Pass clinicId
            email: email,
          ),
        ),
      );
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
                  'Owner/Dentist Verification',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                _buildTextField(firstnameController, 'Firstname', Icons.person),
                SizedBox(height: 10),
                _buildTextField(lastnameController, 'Lastname', Icons.person),
                SizedBox(height: 10),
                _buildTextField(phoneController, 'Phone Number', Icons.phone),
                SizedBox(height: 10),
                Text(
                  '* Reminder: Use this Email and Password to Login *',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 10),
                _buildTextField(emailController, 'Email', Icons.mail,
                    readOnly: true),
                SizedBox(height: 10),
                _buildTextField(passwordController, 'Password', Icons.lock,
                    isPassword: true),
                SizedBox(height: 20),
                _buildSignUpButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// **🔹 Reusable TextField Widget**
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon, color: Colors.indigo[900]),
        ),
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

  /// **🔹 Sign-Up Button Widget**
  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: signUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        padding: EdgeInsets.symmetric(vertical: 13),
        minimumSize: Size(400, 20),
        elevation: 0,
      ),
      child: Text(
        'Sign Up',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[900],
        ),
      ),
    );
  }
}
