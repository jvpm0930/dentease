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
  final bool _obscurePassword = true; // UI-only: toggles password visibility

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching patient details: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient details updated successfully!')),
      );

      Navigator.pop(context, true); // return to profile and refresh
    } catch (e) {
      if (!mounted) return;
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
      await supabase.storage
          .from('patient-profile')
          .remove([filePath]).catchError((_) {});

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
      if (!mounted) return;
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
          title: const Text(
            "Update Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
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
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const SizedBox(height: 8),

                      // Avatar with camera chip
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              child: GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: CircleAvatar(
                                  radius: 76,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (profileUrl != null &&
                                          profileUrl!.isNotEmpty)
                                      ? NetworkImage(profileUrl!)
                                      : const AssetImage('assets/profile.png')
                                          as ImageProvider,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kPrimary,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Fields styled like DentistProfUpdate (TextFields only)
                      _buildInputField(
                        controller: firstnameController,
                        label: 'Firstname',
                        icon: Icons.person,
                        validatorMsg: 'Required',
                      ),
                      _buildInputField(
                        controller: lastnameController,
                        label: 'Lastname',
                        icon: Icons.person_outline,
                        validatorMsg: 'Required',
                      ),
                      _buildInputField(
                        controller: ageController,
                        label: 'Age',
                        icon: Icons.calculate,
                        keyboardType: TextInputType.number,
                        validatorMsg: 'Required',
                      ),
                      _buildDropdownField(
                        label: 'Gender',
                        icon: Icons.wc_rounded,
                        value: genderValue,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                          DropdownMenuItem(
                              value: 'Not Specify', child: Text('Not Specify')),
                        ],
                        onChanged: (val) => setState(() => genderValue = val),
                        validatorMsg: 'Please select gender',
                      ),
                      _buildInputField(
                        controller: phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validatorMsg: 'Required',
                      ),
                      /*
                      _buildPasswordField(
                        controller: passwordController,
                        label: 'Password',
                        icon: Icons.lock,
                        obscureText: _obscurePassword,
                        toggle: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        validatorMsg: 'Required',
                      ),
                       */

                      const SizedBox(height: 20),

                      // Save button (matches profile buttons)
                      ElevatedButton.icon(
                        onPressed: _updatePatientDetails,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: Colors.black26,
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

  // Shared decoration like DentistProfUpdate
  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: kPrimary),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }

  // TextField builder (Dentist style)
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
        keyboardType: keyboardType,
        validator: validatorMsg != null
            ? (value) =>
                value == null || value.trim().isEmpty ? validatorMsg : null
            : null,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: _decoration(label: label, icon: icon),
      ),
    );
  }

  // Password field (Dentist style)
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required VoidCallback toggle,
    String? validatorMsg,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validatorMsg != null
            ? (value) =>
                value == null || value.trim().isEmpty ? validatorMsg : null
            : null,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: _decoration(
          label: label,
          icon: icon,
          suffix: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }

  // Dropdown field (Dentist style)
  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? validatorMsg,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        validator: validatorMsg != null
            ? (val) => val == null ? validatorMsg : null
            : null,
        decoration: _decoration(label: label, icon: icon),
      ),
    );
  }
}
