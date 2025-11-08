import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmEditStaffPage extends StatefulWidget {
  final String staffId;

  const AdmEditStaffPage({super.key, required this.staffId});

  @override
  State<AdmEditStaffPage> createState() => _AdmEditStaffPageState();
}

class _AdmEditStaffPageState extends State<AdmEditStaffPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String selectedRole = 'staff';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    try {
      final response = await supabase
          .from('staffs')
          .select('firstname, lastname, email, phone, role')
          .eq('staff_id', widget.staffId)
          .single();

      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        emailController.text = response['email'] ?? '';
        phoneController.text = response['phone'] ?? '';
        selectedRole = response['role'] ?? 'staff';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching staff details')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateStaffDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await supabase.from('staffs').update({
        'firstname': firstnameController.text,
        'lastname': lastnameController.text,
        'email': emailController.text,
        'phone': phoneController.text,
        'role': selectedRole,
      }).eq('dentist_id', widget.staffId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff details updated successfully!')),
      );

      Navigator.pop(context, true); // Return "true" to refresh details
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating staff details')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Staff Details')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: firstnameController,
                      decoration: const InputDecoration(labelText: 'Firstname'),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: lastnameController,
                      decoration: const InputDecoration(labelText: 'Lastname'),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
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
                      value: ['staff', 'user'].contains(selectedRole)
                          ? selectedRole
                          : 'user',
                      items: ['staff', 'user']
                          .map((role) =>
                              DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedRole = value!),
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateStaffDetails,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
