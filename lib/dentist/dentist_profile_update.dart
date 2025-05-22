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
        'phone': phoneController.text,
      }).eq('dentist_id', widget.dentistId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dentists details updated successfully!')),
      );
      Navigator.pop(context, true); // Return "true" to refresh details
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
      // Delete existing file before uploading a new one
      await supabase.storage.from('dentist-profile').remove([filePath]);

      // Upload image to Supabase Storage
      await supabase.storage.from('dentist-profile').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL after successful upload
      final publicUrl =
          supabase.storage.from('dentist-profile').getPublicUrl(filePath);

      // Update profile URL in database
      await supabase.from('dentists').update({
        'profile_url': publicUrl,
      }).eq('dentist_id', widget.dentistId);

      setState(() {
        // Add a timestamp to the URL to force refresh and bypass cache
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
            "Dentist Update",
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
                          radius: 150,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: profileUrl != null &&
                                  profileUrl!.isNotEmpty
                              ? NetworkImage(profileUrl!)
                              : const AssetImage('assets/default_profile.png')
                                  as ImageProvider,
                          child: profileUrl == null || profileUrl!.isEmpty
                              ? const Icon(Icons.camera_alt,
                                  size: 30, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Align(
                        alignment: Alignment.center,
                        child: Text("1x1 Profile Pic"),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: firstnameController,
                        decoration:
                            const InputDecoration(labelText: 'Firstname'),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastnameController,
                        decoration:
                            const InputDecoration(labelText: 'Lastname'),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _updateDentistDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Button color
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
