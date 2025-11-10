import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PatientProfUpdate extends StatefulWidget {
  final String patientId;

  const PatientProfUpdate({super.key, required this.patientId});

  @override
  State<PatientProfUpdate> createState() => _PatientProfUpdateState();
}

class _PatientProfUpdateState extends State<PatientProfUpdate> {
  static const Color kPrimary = Color(0xFF103D7E);

  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? genderValue;
  String? profileUrl;
  bool isLoading = true;
  final bool _obscurePassword = true; // make it mutable

  @override
  void initState() {
    super.initState();
    _fetchPatientDetails();
  }

  Future<void> _fetchPatientDetails() async {
    try {
      final response = await supabase
          .from('patients')
          .select(
              'firstname, lastname, phone, profile_url, age, gender, password')
          .eq('patient_id', widget.patientId)
          .single();

      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        phoneController.text = response['phone'] ?? '';
        ageController.text = response['age']?.toString() ?? '';
        genderValue = response['gender'];
        passwordController.text = response['password'] ?? '';
        profileUrl = response['profile_url'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching patient details: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updatePatientDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await supabase.from('patients').update({
        'firstname': firstnameController.text.trim(),
        'lastname': lastnameController.text.trim(),
        'phone': phoneController.text.trim(),
        'age': int.tryParse(ageController.text.trim()) ?? 0,
        'gender': genderValue,
        'password': passwordController.text.trim(),
      }).eq('patient_id', widget.patientId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient details updated successfully!')),
      );

      Navigator.pop(context, true); // return to profile and refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating patient details: $e')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final fileName = 'patient_${widget.patientId}.jpg';
    final filePath = 'patient-profile/$fileName';

    try {
      // Remove existing (ignore errors)
      await supabase.storage.from('patient-profile').remove([filePath]);

      await supabase.storage.from('patient-profile').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from('patient-profile').getPublicUrl(filePath);

      await supabase.from('patients').update({
        'profile_url': publicUrl,
      }).eq('patient_id', widget.patientId);

      setState(() {
        profileUrl =
            '$publicUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Update Profile",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      const SizedBox(height: 8),
                      // Avatar (matches style of PatientProfile)
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              (profileUrl != null && profileUrl!.isNotEmpty)
                                  ? NetworkImage(profileUrl!)
                                  : const AssetImage('assets/profile.png')
                                      as ImageProvider,
                          child: (profileUrl == null || profileUrl!.isEmpty)
                              ? const Icon(Icons.camera_alt,
                                  size: 30, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          "UPDATE PROFILE PICTURE",
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Firstname tile
                      _FieldTile(
                        icon: Icons.person,
                        label: "Firstname",
                        child: TextFormField(
                          controller: firstnameController,
                          decoration: _inputNoBorder(hint: 'Enter firstname'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Lastname tile
                      _FieldTile(
                        icon: Icons.person_outline,
                        label: "Lastname",
                        child: TextFormField(
                          controller: lastnameController,
                          decoration: _inputNoBorder(hint: 'Enter lastname'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Age tile
                      _FieldTile(
                        icon: Icons.calculate,
                        label: "Age",
                        child: TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: _inputNoBorder(hint: 'Enter age'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Gender tile
                      _FieldTile(
                        icon: Icons.wc_rounded,
                        label: "Gender",
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<String>(
                            value: genderValue,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Male', child: Text('Male')),
                              DropdownMenuItem(
                                  value: 'Female', child: Text('Female')),
                              DropdownMenuItem(
                                  value: 'Not Specify',
                                  child: Text('Not Specify')),
                            ],
                            onChanged: (value) =>
                                setState(() => genderValue = value),
                            validator: (value) =>
                                value == null ? 'Please select gender' : null,
                            decoration:
                                const InputDecoration(border: InputBorder.none),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Phone tile
                      _FieldTile(
                        icon: Icons.phone,
                        label: "Phone Number",
                        child: TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration:
                              _inputNoBorder(hint: 'Enter phone number'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Save button (matches profile buttons)
                      ElevatedButton.icon(
                        onPressed: _updatePatientDetails,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  InputDecoration _inputNoBorder({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 0),
      suffixIcon: suffix,
    );
  }
}

// Reusable tile that matches PatientProfile info card style
class _FieldTile extends StatelessWidget {
  static const Color kPrimary = Color(0xFF103D7E);

  final IconData icon;
  final String label;
  final Widget child;

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.grey, height: 1.3)),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
