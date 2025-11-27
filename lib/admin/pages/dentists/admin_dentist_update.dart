import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmEditDentistPage extends StatefulWidget {
  final String dentistId;

  const AdmEditDentistPage({super.key, required this.dentistId});

  @override
  State<AdmEditDentistPage> createState() => _AdmEditDentistPageState();
}

class _AdmEditDentistPageState extends State<AdmEditDentistPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String selectedRole = 'user';

  bool isLoading = true;
  static const kPrimary = Color(0xFF103D7E);

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    try {
      final response = await supabase
          .from('dentists')
          .select('firstname, lastname, email, phone, role')
          .eq('dentist_id', widget.dentistId)
          .single();

      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        emailController.text = response['email'] ?? '';
        phoneController.text = response['phone'] ?? '';
        selectedRole = response['role'] ?? 'user';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dentist details')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateDentistDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await supabase.from('dentists').update({
        'firstname': firstnameController.text,
        'lastname': lastnameController.text,
        'email': emailController.text,
        'phone': phoneController.text,
        'role': selectedRole,
      }).eq('dentist_id', widget.dentistId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dentist details updated successfully!')),
      );

      Navigator.pop(context, true); // Return "true" to refresh details
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating dentist details')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Dentist Details')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildInputField(
                      controller: firstnameController,
                      label: 'Firstname',
                      icon: Icons.person,
                      validatorMsg: 'Required',
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: lastnameController,
                      label: 'Lastname',
                      icon: Icons.person_outline,
                      validatorMsg: 'Required',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: ['admin', 'user'].contains(selectedRole)
                          ? selectedRole
                          : 'user',
                      items: ['admin', 'user']
                          .map((role) =>
                              DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedRole = value!),
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateDentistDetails,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? validatorMsg,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        validator: validatorMsg != null
            ? (value) =>
                value == null || value.trim().isEmpty ? validatorMsg : null
            : null,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: kPrimary),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }
}
