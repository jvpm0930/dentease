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
    if (file == null) return;

    try {
      setState(() {
        isLoading = true;
      });

      // Upload image to Supabase Storage (clinic-profile bucket)
      final fileBytes = await file.readAsBytes();
      final fileName =
          'clinic_${widget.clinicId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final response = await supabase.storage
          .from('clinic-profile') 
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(contentType: 'image/jpeg'),
          );

      // Get the public URL of the uploaded image
      final newImageUrl =
          supabase.storage.from('clinic-profile').getPublicUrl(fileName);

      // Update the clinic profile URL in Supabase
      await supabase.from('clinics').update({'profile_url': newImageUrl}).eq(
          'clinic_id', widget.clinicId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile image updated successfully!')),
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
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    await _uploadImage(file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile Image'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Show current image
            widget.profileUrl != null
                ? ClipRRect(
                    borderRadius:
                        BorderRadius.circular(15), // Optional rounded corners
                    child: Image.network(
                      widget.profileUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit
                          .cover, // Ensures the image fills the container properly
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/logo2.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover, // Same fit for fallback
                        );
                      },
                    ),
                  )
                : ClipRRect(
                    borderRadius:
                        BorderRadius.circular(15), // Optional rounded corners
                    child: Image.asset(
                      'assets/logo2.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover, // Fallback image with proper fit
                    ),
                  ),

            const SizedBox(height: 10),
            const Text("1x1 dimension"),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: isLoading ? null : _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Choose New Image', style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
