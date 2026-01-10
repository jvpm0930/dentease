import 'dart:io';
import 'package:dentease/clinic/dentease_locationPick.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditClinicDetails extends StatefulWidget {
  final Map<String, dynamic> clinicDetails;
  final String clinicId;

  const EditClinicDetails({
    super.key,
    required this.clinicDetails,
    required this.clinicId,
  });

  @override
  State<EditClinicDetails> createState() => _EditClinicDetailsState();
}

class _EditClinicDetailsState extends State<EditClinicDetails> {
  final supabase = Supabase.instance.client;

  late TextEditingController clinicNameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController infoController;

  double? latitude;
  double? longitude;

  File? licenseImage;
  String? licenseUrl;

  File? permitImage;
  String? permitUrl;

  File? officeImage;
  String? officeUrl;

  @override
  void initState() {
    super.initState();
    clinicNameController =
        TextEditingController(text: widget.clinicDetails['clinic_name']);
    phoneController =
        TextEditingController(text: widget.clinicDetails['phone']);
    addressController =
        TextEditingController(text: widget.clinicDetails['address']);
    infoController = TextEditingController(text: widget.clinicDetails['info']);

    latitude = (widget.clinicDetails['latitude'] as num?)?.toDouble();
    longitude = (widget.clinicDetails['longitude'] as num?)?.toDouble();
    licenseUrl = widget.clinicDetails['license_url'];
    permitUrl = widget.clinicDetails['permit_url'];
    officeUrl = widget.clinicDetails['office_url'];
  }

  Future<void> _updateClinicDetails() async {
    try {
      final updateData = {
        'clinic_name': clinicNameController.text,
        'phone': phoneController.text,
        'address': addressController.text,
        'info': infoController.text,
        'latitude': latitude,
        'longitude': longitude,
        if (licenseUrl != null) 'license_url': licenseUrl,
        if (permitUrl != null) 'permit_url': permitUrl,
        if (officeUrl != null) 'office_url': officeUrl,
      };

      await supabase
          .from('clinics')
          .update(updateData)
          .eq('clinic_id', widget.clinicId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clinic details updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating clinic details: $e')),
      );
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          initialLat: latitude ?? 0.0,
          initialLng: longitude ?? 0.0,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        latitude = result['latitude'];
        longitude = result['longitude'];
        addressController.text = result['address'];
      });
    }
  }

  Future<String?> _uploadImage({
    required File image,
    required String folder,
    required String fileName,
    String? oldUrl,
  }) async {
    try {
      final filePath = '$folder/$fileName';

      if (oldUrl != null && oldUrl.isNotEmpty) {
        final oldFilePath = oldUrl.split('/$folder/').last;
        if (oldFilePath != fileName) {
          await supabase.storage.from(folder).remove(['$folder/$oldFilePath']);
        }
      }

      await supabase.storage.from(folder).upload(filePath, image,
          fileOptions: const FileOptions(upsert: true));

      return supabase.storage.from(folder).getPublicUrl(filePath);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _pickLicenseImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => licenseImage = File(image.path));
      licenseUrl = await _uploadImage(
        image: licenseImage!,
        folder: 'licenses',
        fileName: '${widget.clinicId}_license.jpg',
        oldUrl: licenseUrl,
      );
      if (!mounted) return;
      if (licenseUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License image uploaded!')),
        );
      }
      setState(() {}); // refresh preview
    }
  }

  Future<void> _pickPermitImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => permitImage = File(image.path));
      permitUrl = await _uploadImage(
        image: permitImage!,
        folder: 'permits',
        fileName: '${widget.clinicId}_permit.jpg',
        oldUrl: permitUrl,
      );
      if (!mounted) return;
      if (permitUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permit image uploaded!')),
        );
      }
      setState(() {});
    }
  }

  Future<void> _pickOfficeImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => officeImage = File(image.path));
      officeUrl = await _uploadImage(
        image: officeImage!,
        folder: 'offices',
        fileName: '${widget.clinicId}_office.jpg',
        oldUrl: officeUrl,
      );
      if (!mounted) return;
      if (officeUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Office image uploaded!')),
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Edit Clinic Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Basic Info
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      icon: Icons.apartment_rounded,
                      title: 'Basic Information',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Clinic Name',
                      clinicNameController,
                      icon: Icons.badge_outlined,
                    ),
                    _buildTextField(
                      'Phone',
                      phoneController,
                      icon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 6),
                    // Address + Pick location
                    TextField(
                      controller: addressController,
                      readOnly: true,
                      decoration: _inputDecoration(
                        label: 'Address',
                        icon: Icons.place_outlined,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.location_searching),
                          onPressed: _pickLocation,
                          tooltip: 'Pick on Map',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (latitude != null && longitude != null)
                      Text(
                        'Lat: ${latitude!.toStringAsFixed(5)}  |  Lng: ${longitude!.toStringAsFixed(5)}',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Documents
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      icon: Icons.assignment_turned_in_rounded,
                      title: 'Credentials & Documents',
                    ),
                    const SizedBox(height: 12),
                    // License
                    _DocRow(
                      title: 'PRC License',
                      onPick: _pickLicenseImage,
                      preview: _buildPreview(licenseImage, licenseUrl),
                    ),
                    const SizedBox(height: 12),
                    // Permit
                    _DocRow(
                      title: 'DTI Permit',
                      onPick: _pickPermitImage,
                      preview: _buildPreview(permitImage, permitUrl),
                    ),
                    const SizedBox(height: 12),
                    // Office
                    _DocRow(
                      title: 'Workplace',
                      onPick: _pickOfficeImage,
                      preview: _buildPreview(officeImage, officeUrl),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Recommended: Square image • JPG/PNG • up to ~2MB",
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // About/Info
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      icon: Icons.notes_rounded,
                      title: 'Clinic Info',
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      'Clinic Info',
                      infoController,
                      maxLines: 6,
                      icon: Icons.description_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateClinicDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable preview builder for file/url
  Widget _buildPreview(File? file, String? url) {
    final border = BorderRadius.circular(10);
    return ClipRRect(
      borderRadius: border,
      child: Container(
        width: double.infinity,
        height: 140,
        color: Colors.grey.shade100,
        child: file != null
            ? Image.file(file, fit: BoxFit.cover)
            : (url != null && url.isNotEmpty)
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _emptyPreview(),
                  )
                : _emptyPreview(),
      ),
    );
  }

  Widget _emptyPreview() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_not_supported_outlined, color: Colors.black38),
          SizedBox(height: 4),
          Text('No image', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }

  // Styled text field
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        maxLines: maxLines,
        decoration: _inputDecoration(label: label, icon: icon),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.primaryBlue) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.dividerColor),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  final String title;
  final VoidCallback onPick;
  final Widget preview;

  const _DocRow({
    required this.title,
    required this.onPick,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppTheme.textDark),
        ),
        const SizedBox(height: 8),
        preview,
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file),
            label: const Text('Change'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: const BorderSide(color: AppTheme.primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
