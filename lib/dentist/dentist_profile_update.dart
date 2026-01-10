import 'dart:io';
import 'package:dentease/theme/app_theme.dart';
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

  // Clinic Controllers
  final TextEditingController clinicNameController = TextEditingController();
  final TextEditingController clinicDescController = TextEditingController();
  final TextEditingController clinicAddressController = TextEditingController();
  final TextEditingController clinicEmailController = TextEditingController();

  String? profileUrl;

  // Clinic Images
  String? clinicLogoUrl;
  String? clinicBannerUrl;
  String? clinicId;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    debugPrint(
        '📡 [DentistProfUpdate] Fetching details for dentistId: ${widget.dentistId}');
    try {
      final response = await supabase
          .from('dentists')
          .select(
              'firstname, lastname, phone, profile_url, fcm_token, clinic_id')
          .eq('dentist_id', widget.dentistId)
          .single();

      debugPrint(
          '✅ [DentistProfUpdate] Dentist data fetched: ${response['firstname']} ${response['lastname']}');

      setState(() {
        firstnameController.text = response['firstname'] ?? '';
        lastnameController.text = response['lastname'] ?? '';
        phoneController.text = response['phone'] ?? '';
        profileUrl = response['profile_url'];
      });

      // Fetch Clinic Details if exists
      final cid = response['clinic_id'];
      if (cid != null) {
        debugPrint(
            '📡 [DentistProfUpdate] Fetching clinic details for ID: $cid');
        final clinicRes = await supabase
            .from('clinics')
            .select(
                'clinic_name, email, address, info, profile_url, office_url')
            .eq('clinic_id', cid)
            .maybeSingle();

        if (clinicRes != null) {
          debugPrint(
              '✅ [DentistProfUpdate] Clinic data fetched: ${clinicRes['clinic_name']}');
          setState(() {
            clinicId = cid;
            clinicNameController.text = clinicRes['clinic_name'] ?? '';
            clinicEmailController.text = clinicRes['email'] ?? '';
            clinicAddressController.text = clinicRes['address'] ?? '';
            clinicDescController.text = clinicRes['info'] ?? '';
            clinicLogoUrl = clinicRes['profile_url'];
            clinicBannerUrl = clinicRes['office_url'];
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dentist details: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateDentistDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      debugPrint('📡 [DentistProfUpdate] Updating dentist info in DB...');
      // Update Dentist
      await supabase.from('dentists').update({
        'firstname': firstnameController.text.trim(),
        'lastname': lastnameController.text.trim(),
        'phone': phoneController.text.trim(),
      }).eq('dentist_id', widget.dentistId);

      // Update Clinic if user is attached to one
      if (clinicId != null) {
        debugPrint('📡 [DentistProfUpdate] Updating clinic info in DB...');
        await supabase.from('clinics').update({
          'clinic_name': clinicNameController.text.trim(),
          'email': clinicEmailController.text.trim(),
          'address': clinicAddressController.text.trim(),
          'info': clinicDescController.text.trim(),
        }).eq('clinic_id', clinicId!);
      }
      debugPrint('✅ [DentistProfUpdate] Update completed successfully');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context, true); // refresh parent screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating details: $e')),
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
      debugPrint('📡 [DentistProfUpdate] Uploading profile image...');
      // Remove previous if exists (ignore error if not found)
      await supabase.storage
          .from('dentist-profile')
          .remove([filePath]).catchError((_) => <FileObject>[]);

      await supabase.storage.from('dentist-profile').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from('dentist-profile').getPublicUrl(filePath);
      debugPrint('✅ [DentistProfUpdate] Image uploaded: $publicUrl');

      debugPrint('📡 [DentistProfUpdate] Updating profile URL in DB...');
      await supabase.from('dentists').update({'profile_url': publicUrl}).eq(
          'dentist_id', widget.dentistId);
      debugPrint('✅ [DentistProfUpdate] DB updated successfully');

      setState(() {
        profileUrl =
            '$publicUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}';
      });

      if (!mounted) return;
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
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            "Edit Profile",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D2A7A)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Avatar with camera chip (tap to change)
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.9),
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
                                    color: AppTheme.primaryBlue,
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

                      const SizedBox(height: 24),

                      // Editable fields styled like PatientProfile tiles
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

                      if (clinicId != null) ...[
                        const SizedBox(height: 32),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 16),

                        Text(
                          "Clinic Details",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(height: 16),

                        // Clinic Images Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildImagePicker(
                                label: "Logo",
                                imageUrl: clinicLogoUrl,
                                onTap: _pickClinicLogo),
                            _buildImagePicker(
                                label: "Banner/Frontal",
                                imageUrl: clinicBannerUrl,
                                onTap: _pickClinicBanner,
                                isWide: true),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _buildInputField(
                          controller: clinicNameController,
                          label: 'Clinic Name',
                          icon: Icons.business,
                          validatorMsg: 'Required',
                        ),
                        _buildInputField(
                          controller: clinicDescController,
                          label: 'Description / About',
                          icon: Icons.description,
                          maxLines: 3,
                        ),
                        _buildInputField(
                          controller: clinicAddressController,
                          label: 'Address',
                          icon: Icons.location_on,
                        ),
                        _buildInputField(
                          controller: clinicEmailController,
                          label: 'Clinic Email',
                          icon: Icons.email,
                        ),
                      ],

                      const SizedBox(height: 24),

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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
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

  Widget _buildImagePicker({
    required String label,
    required String? imageUrl,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: isWide ? 160 : 100,
              height: 100,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(imageUrl), fit: BoxFit.cover)
                      : null,
                  border: Border.all(color: Colors.grey.shade300)),
              child: imageUrl == null
                  ? Center(
                      child: Icon(Icons.add_a_photo, color: Colors.grey[400]))
                  : null,
            ),
            InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue, shape: BoxShape.circle),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }

  /// Styled input field matching PatientProfile look-and-feel
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? validatorMsg,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
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
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
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
            borderSide:
                const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }

  // Generic Image Picker
  Future<void> _pickImageGeneric(
      String bucket, String folder, Function(String) onUrlUpdate) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final filePath = '$folder/$fileName';

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...')),
        );
      }

      await supabase.storage.from(bucket).upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(filePath);

      onUrlUpdate(publicUrl);

      if (mounted) {
        setState(() {}); // Trigger rebuild to show new image
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image uploaded! Remember to click Save Changes.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e')),
        );
      }
    }
  }

  // Specific wrappers
  Future<void> _pickClinicLogo() async {
    if (clinicId == null) return;

    await _pickImageGeneric('dentist-profile', 'clinic_logos', (url) async {
      setState(() => clinicLogoUrl = url);
      // Check if immediate save is desired. For now, we update state and wait for save button
      // OR simple update here if we want instant image feedback on the profile.
      // User experience: Image updates are often instant.
      // The previous code had instant DB update for images. Stick to that.
      await supabase
          .from('clinics')
          .update({'profile_url': url}).eq('clinic_id', clinicId!);
    });
  }

  Future<void> _pickClinicBanner() async {
    if (clinicId == null) return;
    await _pickImageGeneric('dentist-profile', 'clinic_banners', (url) async {
      setState(() => clinicBannerUrl = url);
      await supabase
          .from('clinics')
          .update({'office_url': url}).eq('clinic_id', clinicId!);
    });
  }
}
