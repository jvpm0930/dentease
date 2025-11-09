import 'dart:io';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistProfUpdate extends StatefulWidget {
  final String dentistId;

  const DentistProfUpdate({super.key, required this.dentistId});

  @override
  State<DentistProfUpdate> createState() => _DentistProfUpdateState();
}

class _DentistProfUpdateState extends State<DentistProfUpdate> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String? profileUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    try {
      final response = await supabase
          .from('dentists')
          .select('firstname, lastname, phone, profile_url')
          .eq('dentist_id', widget.dentistId)
          .single();

      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        phoneController.text = response['phone'] ?? '';
        profileUrl = response['profile_url'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dentist details: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateDentistDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await supabase.from('dentists').update({
        'firstname': firstnameController.text,
        'lastname': lastnameController.text,
        'phone': phoneController.text,
      }).eq('dentist_id', widget.dentistId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dentist details updated successfully!')),
      );
      Navigator.pop(context, true); // refresh parent screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating dentist details: $e')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    final fileName = 'dentist_${widget.dentistId}.jpg';
    final filePath = 'dentist-profile/$fileName';

    try {
      await supabase.storage.from('dentist-profile').remove([filePath]);
      await supabase.storage.from('dentist-profile').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from('dentist-profile').getPublicUrl(filePath);

      await supabase.from('dentists').update({
        'profile_url': publicUrl,
      }).eq('dentist_id', widget.dentistId);

      setState(() {
        profileUrl =
            '$publicUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
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
            "Edit Profile",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Profile Picture with tap to upload
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: profileUrl != null &&
                                  profileUrl!.isNotEmpty
                              ? NetworkImage(profileUrl!)
                              : const AssetImage('assets/default_profile.png')
                                  as ImageProvider,
                          child: profileUrl == null || profileUrl!.isEmpty
                              ? const Icon(Icons.camera_alt,
                                  size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "UPDATE PROFILE PICTURE",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 30),

                      // Editable TextFields
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
                        controller: phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 30),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _updateDentistDetails,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            'Save Changes',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Styled input field for consistent look
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? validatorMsg,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: validatorMsg != null
            ? (value) => value!.isEmpty ? validatorMsg : null
            : null,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
