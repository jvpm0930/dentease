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
  bool _obscurePassword = true;

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
      setState(() {
        isLoading = false;
      });
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

      Navigator.pop(context, true); // Return "true" to refresh details
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
          title: const Text(
            "Update Profile",
            style: TextStyle(color: Colors.white),
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
                    children: [
                      // Profile Picture
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              profileUrl != null && profileUrl!.isNotEmpty
                                  ? NetworkImage(profileUrl!)
                                  : const AssetImage('assets/profile.png')
                                      as ImageProvider,
                          child: profileUrl == null || profileUrl!.isEmpty
                              ? const Icon(Icons.camera_alt,
                                  size: 30, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const Align(
                        alignment: Alignment.center,
                        child: Text("Tap to update profile picture"),
                      ),
                      const SizedBox(height: 30),

                      // Firstname
                      TextFormField(
                        controller: firstnameController,
                        decoration: const InputDecoration(
                            labelText: 'Firstname',
                            prefixIcon: Icon(
                              Icons.person,
                              color: Colors.blueAccent,
                            )),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),

                      // Lastname
                      TextFormField(
                        controller: lastnameController,
                        decoration: const InputDecoration(
                            labelText: 'Lastname',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.blueAccent,
                            )),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),

                      // Phone Number
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(
                              Icons.phone,
                              color: Colors.blueAccent,
                            )),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),

                      // Age
                      TextFormField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Age',
                            prefixIcon: Icon(
                              Icons.calculate,
                              color: Colors.blueAccent,
                            )),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: genderValue,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(
                            Icons.wc_rounded,
                            color: Colors.blueAccent,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                          DropdownMenuItem(
                              value: 'Not Specify', child: Text('Not Specify')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            genderValue = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Please select gender' : null,
                      ),
                      const SizedBox(height: 10),

                      // Password
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Colors.blueAccent,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 15),

                      // Save Button
                      ElevatedButton.icon(
                        onPressed: _updatePatientDetails,
                        icon: const Icon(Icons.save,
                            color: Colors.white), // <-- Save icon
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
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
}
