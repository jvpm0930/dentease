import 'package:dentease/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistAddDentist extends StatefulWidget {
  final String clinicId;

  const DentistAddDentist({super.key, required this.clinicId});

  @override
  _DentistAddDentistState createState() => _DentistAddDentistState();
}

class _DentistAddDentistState extends State<DentistAddDentist> {
  final supabase = Supabase.instance.client;

  final firstnameController = TextEditingController();
  final lastnameController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  
  bool isLoading = false;

  @override
  void dispose() {
    firstnameController.dispose();
    lastnameController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> createDentist() async {
    try {
      final firstname = firstnameController.text.trim();
      final lastname = lastnameController.text.trim();
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // Validation
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
      
      setState(() => isLoading = true);

      // Call Edge Function for server-side user creation
      final response = await supabase.functions.invoke(
        'create_user',
        body: {
          'email': email,
          'password': password,
          'role': 'dentist',
          'clinic_id': widget.clinicId,
          'profile_data': {
            'firstname': firstname,
            'lastname': lastname,
            'phone': phone,
            'status': 'pending', // Associate dentists need admin approval
          },
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        
        if (data['success'] == true) {
          _showSnackbar('Associate dentist added! Status: Pending approval.');
          
          // Navigate back to dentist list (current dentist stays logged in)
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          _showSnackbar('Error: ${data['error'] ?? 'Failed to create dentist'}');
        }
      } else {
        _showSnackbar('Server error: ${response.status}');
      }
    } catch (e) {
      debugPrint('Error creating dentist: $e');
      _showSnackbar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Add Associate Dentist',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Image.asset('assets/logo2.png', width: 250),
                const SizedBox(height: 20),
                const Text(
                  'Add Associate Dentist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(emailController, 'Email', Icons.mail),
                const SizedBox(height: 10),
                _buildTextField(passwordController, 'Password', Icons.lock,
                    isPassword: true),
                const SizedBox(height: 10),
                _buildTextField(firstnameController, 'First Name', Icons.person),
                const SizedBox(height: 10),
                _buildTextField(lastnameController, 'Last Name', Icons.person),
                const SizedBox(height: 10),
                _buildTextField(phoneController, 'Phone Number', Icons.phone),
                const SizedBox(height: 20),
                
                isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _buildAddButton(),
                
                const SizedBox(height: 12),
                const Text(
                  'Note: Associate dentists require admin approval',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
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
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon, color: const Color(0xFF103D7E)),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton(
      onPressed: createDentist,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
        elevation: 2,
      ),
      child: const Text(
        'Add Dentist',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF103D7E),
        ),
      ),
    );
  }
}
