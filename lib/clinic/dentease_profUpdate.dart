import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateProfileImage extends StatefulWidget {
  final String clinicId;
  final String? profileUrl;

  const UpdateProfileImage({
    super.key,
    required this.clinicId,
    this.profileUrl,
  });

  @override
  _UpdateProfileImageState createState() => _UpdateProfileImageState();
}

class _UpdateProfileImageState extends State<UpdateProfileImage> {
  final supabase = Supabase.instance.client;
  bool isLoading = false;

  Future<void> _uploadImage(XFile? file) async {
    if (file == null) {
      debugPrint('📸 [ClinicProfUpdate] No image selected');
      return;
    }

    try {
      debugPrint('📸 [ClinicProfUpdate] Starting upload for: ${file.path}');
      setState(() {
        isLoading = true;
      });

      final fileBytes = await file.readAsBytes();
      final fileName =
          'clinic_${widget.clinicId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint(
          '📡 [ClinicProfUpdate] Uploading to Storage bucket: clinic-profile');
      await supabase.storage.from('clinic-profile').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final newImageUrl =
          supabase.storage.from('clinic-profile').getPublicUrl(fileName);
      debugPrint(
          '✅ [ClinicProfUpdate] Image uploaded. Public URL: $newImageUrl');

      debugPrint('📡 [ClinicProfUpdate] Updating clinic record in DB...');
      await supabase.from('clinics').update({'profile_url': newImageUrl}).eq(
          'clinic_id', widget.clinicId);
      debugPrint('✅ [ClinicProfUpdate] DB updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    await _uploadImage(file);
  }

  @override
  Widget build(BuildContext context) {
    // Cache-bust the preview so updated images show right away
    final displayUrl =
        (widget.profileUrl != null && widget.profileUrl!.isNotEmpty)
            ? '${widget.profileUrl}?t=${DateTime.now().millisecondsSinceEpoch}'
            : null;

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Update Profile Image',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Card preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.dividerColor),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        // Image preview (1x1 style)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 220,
                            height: 220,
                            color: Colors.grey.shade200,
                            child: displayUrl != null
                                ? Image.network(
                                    displayUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/logo2.png',
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : Image.asset(
                                    'assets/logo2.png',
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Recommended: 1x1 (square), JPG/PNG • Max ~2MB",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.dividerColor),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.photo, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              "Select a new image",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        final picker = ImagePicker();
                                        final file = await picker.pickImage(
                                          source: ImageSource.gallery,
                                        );
                                        await _uploadImage(file);
                                      },
                                icon: const Icon(Icons.image),
                                label: const Text('Gallery'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(
                                      color: AppTheme.primaryBlue),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        final picker = ImagePicker();
                                        final file = await picker.pickImage(
                                          source: ImageSource.camera,
                                        );
                                        await _uploadImage(file);
                                      },
                                icon: const Icon(Icons.photo_camera),
                                label: const Text('Camera'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(
                                      color: AppTheme.primaryBlue),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "After selecting, upload will start automatically.",
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Loading overlay
            if (isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
