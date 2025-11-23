import 'dart:io';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController phoneController = TextEditingController();

  String? profileUrl;
  bool isLoading = true;

  // Match DentistProfUpdate styling
  static const kPrimary = Color(0xFF103D7E);

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

      if (!mounted) return;
      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        phoneController.text = response['phone'] ?? '';
        profileUrl = response['profile_url'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching staff details: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateStaffDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await supabase.from('staffs').update({
        'firstname': firstnameController.text.trim(),
        'lastname': lastnameController.text.trim(),
        'phone': phoneController.text.trim(),
      }).eq('staff_id', widget.staffId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff details updated successfully!')),
      );
      Navigator.pop(context, true); // refresh parent screen
    } catch (e) {
      if (!mounted) return;
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
      // Remove previous if exists (ignore error if not found)
      await supabase.storage
          .from('staff-profile')
          .remove([filePath]).catchError((_) {});

      await supabase.storage.from('staff-profile').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from('staff-profile').getPublicUrl(filePath);

      await supabase
          .from('staffs')
          .update({'profile_url': publicUrl}).eq('staff_id', widget.staffId);

      if (!mounted) return;
      setState(() {
        profileUrl =
            '$publicUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
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
            "Edit Profile",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Avatar with camera chip (tap to change) - same as dentist
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
                              child: CircleAvatar(
                                radius: 76,
                                backgroundColor: Colors.grey[200],
                                backgroundImage:
                                    profileUrl != null && profileUrl!.isNotEmpty
                                        ? NetworkImage(profileUrl!)
                                        : const AssetImage('assets/profile.png')
                                            as ImageProvider,
                              ),
                            ),
                            // Camera chip
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
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Editable fields styled like DentistProfUpdate
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

                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _updateStaffDetails,
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
                              vertical: 14,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor: Colors.black26,
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

  // Styled input field matching DentistProfUpdate look-and-feel
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
