import 'dart:io';
import 'package:dentease/clinic/dentease_locationPick.dart';
import 'package:dentease/widgets/background_cont.dart';
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
  File? licenseImage; // Store picked image as File
  String? licenseUrl; // Store license URL from storage
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

    latitude = widget.clinicDetails['latitude'];
    longitude = widget.clinicDetails['longitude'];
    licenseUrl =
        widget.clinicDetails['license_url']; // Load existing license URL
    permitUrl = widget.clinicDetails['permit_url'];
    officeUrl = widget.clinicDetails['office_url'];
  }

  /// Update clinic details in Supabase
  Future<void> _updateClinicDetails() async {
    try {
      //  Prepare data to update
      final updateData = {
        'clinic_name': clinicNameController.text,
        'phone': phoneController.text,
        'address': addressController.text,
        'info': infoController.text,
        'latitude': latitude,
        'longitude': longitude,
        if (licenseUrl != null)
          'license_url': licenseUrl,
        if (permitUrl != null) 'permit_url': permitUrl,
        if (officeUrl != null) 'office_url': officeUrl,
      };


      //  Update clinic details in Supabase
      await supabase
          .from('clinics')
          .update(updateData)
          .eq('clinic_id', widget.clinicId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clinic details updated successfully!')),
      );

      Navigator.pop(context, true); // Return true to refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating clinic details: $e')),
      );
    }
  }

  /// Open Map to pick a location
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

      // Delete old file if exists
      if (oldUrl != null && oldUrl.isNotEmpty) {
        final oldFilePath = oldUrl.split('/$folder/').last;
        if (oldFilePath != fileName) {
          await supabase.storage.from(folder).remove(['$folder/$oldFilePath']);
        }
      }

      // Upload with upsert
      await supabase.storage.from(folder).upload(filePath, image,
          fileOptions: const FileOptions(upsert: true));

      // Return public URL
      return supabase.storage.from(folder).getPublicUrl(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _pickLicenseImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => licenseImage = File(image.path));

      licenseUrl = await _uploadImage(
        image: licenseImage!,
        folder: 'licenses',
        fileName: '${widget.clinicId}_license.jpg',
        oldUrl: licenseUrl,
      );

      if (licenseUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License image uploaded!')),
        );
      }
    }
  }

  Future<void> _pickPermitImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => permitImage = File(image.path));

      permitUrl = await _uploadImage(
        image: permitImage!,
        folder: 'permits',
        fileName: '${widget.clinicId}_permit.jpg',
        oldUrl: permitUrl,
      );

      if (permitUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permit image uploaded!')),
        );
      }
    }
  }

  Future<void> _pickOfficeImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => officeImage = File(image.path));

      officeUrl = await _uploadImage(
        image: officeImage!,
        folder: 'offices',
        fileName: '${widget.clinicId}_office.jpg',
        oldUrl: officeUrl,
      );

      if (officeUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Office image uploaded!')),
        );
      }
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
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildTextField('Clinic Name', clinicNameController),
                _buildTextField('Phone', phoneController),

                // Address TextField + Pick Location Button
                TextField(
                  controller: addressController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.location_on),
                      onPressed: _pickLocation,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // Pick License Image Button
                ElevatedButton.icon(
                  onPressed: _pickLicenseImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text(
                    'Pick License Image',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),

                ElevatedButton.icon(
                  onPressed: _pickPermitImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text(
                    'Pick Permit Image',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),

                ElevatedButton.icon(
                  onPressed: _pickOfficeImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text(
                    'Pick Office Image',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),

                _buildTextField('Clinic Info', infoController, maxLines: 8),
                const SizedBox(height: 20),

                // Save Changes Button
                ElevatedButton(
                  onPressed: _updateClinicDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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

  /// Helper to create a TextField with consistent styling
  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType:
            maxLines == 1 ? TextInputType.text : TextInputType.multiline,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
