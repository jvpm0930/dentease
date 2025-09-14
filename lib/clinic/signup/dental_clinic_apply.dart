  import 'dart:io';
  import 'package:dentease/clinic/signup/dental_success.dart';
import 'package:flutter/material.dart';
  import 'package:dentease/widgets/background_container.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import 'address_picker.dart';

  class DentistApplyPage extends StatefulWidget {
    final String clinicId; // Clinic ID passed from previous screens
    final String email; // Email passed from DentalApplyFirst

    const DentistApplyPage({
      super.key,
      required this.clinicId,
      required this.email,
    });

    @override
    State<DentistApplyPage> createState() => _DentistApplyPageState();
  }

  class _DentistApplyPageState extends State<DentistApplyPage> {
    String? selectedAddress;
    double? latitude;
    double? longitude;
    File? licenseImage;
    File? permitImage;
    File? officeImage;

    final supabase = Supabase.instance.client;

    Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        if (type == "license") {
          licenseImage = File(pickedFile.path);
        } else if (type == "permit") {
          permitImage = File(pickedFile.path);
        } else if (type == "office") {
          officeImage = File(pickedFile.path);
        }
      });
    }
  }

    Future<void> _submitApplication() async {
      if (licenseImage == null ||
      permitImage == null ||
      officeImage == null ||
          selectedAddress == null ||
          latitude == null ||
          longitude == null) {
        _showSnackbar(
            'Please fill all fields, select an address, and upload a license image.');
        return;
      }

      try {
      final supabase = Supabase.instance.client;

      // --- License Upload ---
      String? licenseUrl;
      if (licenseImage != null) {
        final licenseFileName =
            '${DateTime.now().millisecondsSinceEpoch}_license.jpg';
        final licenseFilePath = 'licenses/$licenseFileName';
        await supabase.storage
            .from('licenses')
            .upload(licenseFilePath, licenseImage!);
        licenseUrl =
            supabase.storage.from('licenses').getPublicUrl(licenseFilePath);
      }

      // --- Permit Upload ---
      String? permitUrl;
      if (permitImage != null) {
        final permitFileName =
            '${DateTime.now().millisecondsSinceEpoch}_permit.jpg';
        final permitFilePath = 'permits/$permitFileName';
        await supabase.storage
            .from('permits')
            .upload(permitFilePath, permitImage!);
        permitUrl =
            supabase.storage.from('permits').getPublicUrl(permitFilePath);
      }

      // --- Office Upload ---
      String? officeUrl;
      if (officeImage != null) {
        final officeFileName =
            '${DateTime.now().millisecondsSinceEpoch}_office.jpg';
        final officeFilePath = 'offices/$officeFileName';
        await supabase.storage
            .from('offices')
            .upload(officeFilePath, officeImage!);
        officeUrl =
            supabase.storage.from('offices').getPublicUrl(officeFilePath);
      }

      // --- Update clinic record ---
      await supabase.from('clinics').update({
        'address': selectedAddress,
        'latitude': latitude,
        'longitude': longitude,
        'license_url': licenseUrl,
        'permit_url': permitUrl,
        'office_url': officeUrl,
      }).eq('clinic_id', widget.clinicId);

      // Navigate to success page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DentalSuccess()),
      );

      // Clear the form fields
      setState(() {
        licenseImage = null;
        permitImage = null;
        officeImage = null;
        selectedAddress = null;
        latitude = null;
        longitude = null;
      });
    } catch (e) {
      _showSnackbar('Error submitting application: $e');
    }

    }

    void _showSnackbar(String message) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> _selectAddress() async {
      // Navigate to the address picker screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddressPickerScreen(
            onAddressSelected: (address, lat, lng) {
              setState(() {
                selectedAddress = address;
                latitude = lat;
                longitude = lng;
              });
            },
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return BackgroundContainer(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Image.asset('assets/logo2.png', width: 500),
                  const Text(
                    'Clinic Verification',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectAddress,
                      child: Text(
                        selectedAddress ?? 'Select Address on Map',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                 SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage("license"),
                    icon: const Icon(Icons.upload_file),
                    label: const Text(
                      'Upload License Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                if (licenseImage != null) const SizedBox(height: 8),
                if (licenseImage != null)
                  const Text(
                    'License image selected.',
                    style: TextStyle(color: Colors.black),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage("permit"),
                    icon: const Icon(Icons.upload_file),
                    label: const Text(
                      'Upload Permit Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                if (permitImage != null) const SizedBox(height: 8),
                if (permitImage != null)
                  const Text(
                    'Permit image selected.',
                    style: TextStyle(color: Colors.black),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage("office"),
                    icon: const Icon(Icons.upload_file),
                    label: const Text(
                      'Upload Office Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                if (officeImage != null) const SizedBox(height: 8),
                if (officeImage != null)
                  const Text(
                    'Office image selected.',
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitApplication,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
  }
