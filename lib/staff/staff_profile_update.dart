import 'dart:io';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class StaffProfUpdate extends StatefulWidget {
  final String staffId;

  const StaffProfUpdate({super.key, required this.staffId});

  @override
  State<StaffProfUpdate> createState() => _StaffProfUpdateState();
}

class _StaffProfUpdateState extends State<StaffProfUpdate> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

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
          .select('firstname, lastname, phone, profile_url, fcm_token')
          .eq('staff_id', widget.staffId)
          .single();

      if (!mounted) return;
      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        phoneController.text = response['phone'] ?? '';
        profileUrl = response['profile_url'];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching staff details: $e')),
      );
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
      try {
        await supabase.storage.from('staff-profile').remove([filePath]);
      } catch (_) {
        // Ignore error if file doesn't exist
      }

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
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            "Edit Profile",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppTheme.primaryBlue,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Avatar with camera chip
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor:
                                    AppTheme.primaryBlue.withValues(alpha: 0.1),
                                backgroundImage:
                                    profileUrl != null && profileUrl!.isNotEmpty
                                        ? NetworkImage(profileUrl!)
                                        : null,
                                child: profileUrl == null || profileUrl!.isEmpty
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: 60,
                                        color: AppTheme.primaryBlue,
                                      )
                                    : null,
                              ),
                            ),
                            // Camera button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryBlue,
                                    boxShadow: AppTheme.cardShadow,
                                  ),
                                  padding: const EdgeInsets.all(12),
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

                      const SizedBox(height: 32),

                      // Form fields
                      _buildInputField(
                        controller: firstnameController,
                        label: 'First Name',
                        icon: Icons.person_outline,
                        validatorMsg: 'First name is required',
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: lastnameController,
                        label: 'Last Name',
                        icon: Icons.person,
                        validatorMsg: 'Last name is required',
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _updateStaffDetails,
                          icon: const Icon(Icons.save_outlined, size: 20),
                          label: Text(
                            'Save Changes',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? validatorMsg,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextFormField(
        controller: controller,
        validator: validatorMsg != null
            ? (value) =>
                value == null || value.trim().isEmpty ? validatorMsg : null
            : null,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: AppTheme.textDark,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: AppTheme.textGrey,
          ),
          prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
          ),
        ),
      ),
    );
  }
}
