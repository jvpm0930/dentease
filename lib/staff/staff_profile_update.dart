import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class StaffProfUpdate extends StatefulWidget {
  final String staffId;

  const StaffProfUpdate({super.key, required this.staffId});

  @override
  State<StaffProfUpdate> createState() => _StaffProfUpdateState();
}

class _StaffProfUpdateState extends State<StaffProfUpdate> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String selectedRole = 'staff';
  String? profileUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffDetails();
  }

  Future<void> _fetchStaffDetails() async {
    try {
      final response = await supabase
          .from('staffs')
          .select('firstname, lastname, phone, profile_url')
          .eq('staff_id', widget.staffId)
          .single();

      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        phoneController.text = response['phone'] ?? '';
        profileUrl = response['profile_url'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching staff details: $e')),
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
        'phone': phoneController.text,
      }).eq('staff_id', widget.staffId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff details updated successfully!')),
      );

      Navigator.pop(context, true); // Return "true" to refresh details
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating staff details: $e')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final fileName = 'staff_${widget.staffId}.jpg';
    final filePath = 'staff-profile/$fileName';

    try {
      // Delete existing file before uploading a new one
      await supabase.storage.from('staff-profile').remove([filePath]);

      // Upload image to Supabase Storage
      await supabase.storage.from('staff-profile').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL after successful upload
      final publicUrl =
          supabase.storage.from('staff-profile').getPublicUrl(filePath);

      // Update profile URL in database
      await supabase.from('staffs').update({
        'profile_url': publicUrl,
      }).eq('staff_id', widget.staffId);

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
          "Staff update",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // Remove shadow
        iconTheme: const IconThemeData(color: Colors.white), // White icons
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: CircleAvatar(
                        radius: 150,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            profileUrl != null && profileUrl!.isNotEmpty
                                ? NetworkImage(profileUrl!)
                                : const AssetImage('assets/default_profile.png')
                                    as ImageProvider,
                        child: profileUrl == null || profileUrl!.isEmpty
                            ? const Icon(Icons.camera_alt,
                                size: 30, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.center,
                      child: Text("1x1 Profile Pic"),
                    ),
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
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateStaffDetails,
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
    ));
  }
}
