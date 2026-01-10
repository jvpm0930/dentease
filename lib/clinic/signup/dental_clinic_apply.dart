import 'dart:io';
import 'package:dentease/clinic/signup/dental_success.dart';
import 'package:dentease/services/connectivity_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:dentease/widgets/background_container.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'address_picker.dart';

class DentistApplyPage extends StatefulWidget {
  final String clinicId; // Clinic ID passed from previous screens
  final String email; // Email passed from DentalApplyFirst
  final bool isEditMode; // True when resubmitting after rejection

  const DentistApplyPage({
    super.key,
    required this.clinicId,
    required this.email,
    this.isEditMode = false,
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
  File? profileImage;
  File? frontalImage; // Added frontal image

  // For edit mode - existing URLs from database
  String? existingLicenseUrl;
  String? existingPermitUrl;
  String? existingOfficeUrl;
  String? existingProfileUrl;
  String? existingFrontalUrl; // Added existing frontal URL
  String? clinicName;
  bool isLoading = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🎬 [ClinicApply] Initializing for clinicId: ${widget.clinicId}');
    debugPrint(
        '🎬 [ClinicApply] Mode: ${widget.isEditMode ? 'EDIT/RESUBMIT' : 'INITIAL'}');
    if (widget.isEditMode) {
      _fetchExistingData();
    }
  }

  /// Fetch existing clinic data for edit mode
  Future<void> _fetchExistingData() async {
    debugPrint('📡 [ClinicApply] Fetching existing clinic data...');
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('clinics')
          .select(
              'clinic_name, address, latitude, longitude, license_url, permit_url, office_url, profile_url, frontal_image_url')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (response != null) {
        debugPrint(
            '📊 [ClinicApply] Data fetched successfully: ${response['clinic_name']}');
        setState(() {
          clinicName = response['clinic_name'];
          selectedAddress = response['address'];
          latitude = response['latitude']?.toDouble();
          longitude = response['longitude']?.toDouble();
          existingLicenseUrl = response['license_url'];
          existingPermitUrl = response['permit_url'];
          existingOfficeUrl = response['office_url'];
          existingProfileUrl = response['profile_url'];
          existingFrontalUrl = response['frontal_image_url'];
        });
      }
    } catch (e) {
      _showSnackbar('Error loading existing data');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImage(String type) async {
    debugPrint('📸 [ClinicApply] Picking image for: $type');
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      debugPrint('📸 [ClinicApply] Image picked: ${pickedFile.path}');
      setState(() {
        if (type == "license") {
          licenseImage = File(pickedFile.path);
        } else if (type == "permit") {
          permitImage = File(pickedFile.path);
        } else if (type == "office") {
          officeImage = File(pickedFile.path);
        } else if (type == "profile") {
          profileImage = File(pickedFile.path);
        } else if (type == "frontal") {
          frontalImage = File(pickedFile.path);
        }
      });
    } else {
      debugPrint('📸 [ClinicApply] Image picking cancelled');
    }
  }

  Future<void> _submitApplication() async {
    // In edit mode, allow using existing images if new ones weren't selected
    final hasLicense = licenseImage != null ||
        (widget.isEditMode && existingLicenseUrl != null);
    final hasPermit =
        permitImage != null || (widget.isEditMode && existingPermitUrl != null);
    final hasOffice =
        officeImage != null || (widget.isEditMode && existingOfficeUrl != null);
    final hasFrontal = frontalImage != null ||
        (widget.isEditMode && existingFrontalUrl != null);

    debugPrint('🏥 [ClinicApply] Attempting to submit application...');
    debugPrint('📊 [ClinicApply] Validation status:');
    debugPrint('   - hasLicense: $hasLicense');
    debugPrint('   - hasPermit: $hasPermit');
    debugPrint('   - hasOffice: $hasOffice');
    debugPrint('   - hasFrontal: $hasFrontal');
    debugPrint('   - selectedAddress: ${selectedAddress != null}');
    debugPrint('   - coordinates: $latitude, $longitude');

    // Frontal image is required (based on "clinic needs to add")
    if (!hasLicense ||
        !hasPermit ||
        !hasOffice ||
        !hasFrontal ||
        selectedAddress == null ||
        latitude == null ||
        longitude == null) {
      debugPrint('⚠️ [ClinicApply] Validation FAILED');
      _showSnackbar(
          'Please fill all fields, select an address, and upload all required images.');
      return;
    }

    // Check internet connectivity before proceeding
    try {
      debugPrint('📡 [ClinicApply] Checking connectivity...');
      final connectivityService = ConnectivityService();
      final hasInternet = await connectivityService.hasInternetConnection();
      if (!hasInternet) {
        debugPrint('❌ [ClinicApply] No internet access');
        _showSnackbar(
            'No internet connection. Please check your connection and try again.');
        return;
      }
      debugPrint('✅ [ClinicApply] Connectivity OK');
    } catch (e) {
      debugPrint('⚠️ [ClinicApply] Connectivity check errored: $e');
    }

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Check if user is authenticated
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ [ClinicApply] User NOT authenticated');
        throw Exception('User not authenticated. Please log in again.');
      }

      debugPrint('👤 [ClinicApply] Current user: ${user.id}');

      // --- License Upload (only if new image selected) ---
      String? licenseUrl = existingLicenseUrl;
      if (licenseImage != null) {
        debugPrint('📡 [ClinicApply] Uploading NEW license image...');
        final licenseFileName =
            '${DateTime.now().millisecondsSinceEpoch}_license.jpg';
        final licenseFilePath = 'licenses/$licenseFileName';
        await supabase.storage
            .from('licenses')
            .upload(licenseFilePath, licenseImage!);
        licenseUrl =
            supabase.storage.from('licenses').getPublicUrl(licenseFilePath);
        debugPrint('✅ [ClinicApply] License uploaded: $licenseUrl');
      }

      // --- Permit Upload (only if new image selected) ---
      String? permitUrl = existingPermitUrl;
      if (permitImage != null) {
        debugPrint('📡 [ClinicApply] Uploading NEW permit image...');
        final permitFileName =
            '${DateTime.now().millisecondsSinceEpoch}_permit.jpg';
        final permitFilePath = 'permits/$permitFileName';
        await supabase.storage
            .from('permits')
            .upload(permitFilePath, permitImage!);
        permitUrl =
            supabase.storage.from('permits').getPublicUrl(permitFilePath);
        debugPrint('✅ [ClinicApply] Permit uploaded: $permitUrl');
      }

      // --- Office Upload (only if new image selected) ---
      String? officeUrl = existingOfficeUrl;
      if (officeImage != null) {
        debugPrint('📡 [ClinicApply] Uploading NEW office image...');
        final officeFileName =
            '${DateTime.now().millisecondsSinceEpoch}_office.jpg';
        final officeFilePath = 'offices/$officeFileName';
        await supabase.storage
            .from('offices')
            .upload(officeFilePath, officeImage!);
        officeUrl =
            supabase.storage.from('offices').getPublicUrl(officeFilePath);
        debugPrint('✅ [ClinicApply] Office uploaded: $officeUrl');
      }

      // --- Profile/Featured Image Upload (only if new image selected) ---
      String? profileUrl = existingProfileUrl;
      if (profileImage != null) {
        debugPrint('📡 [ClinicApply] Uploading NEW profile image...');
        final profileFileName =
            '${DateTime.now().millisecondsSinceEpoch}_profile.jpg';
        final profileFilePath = 'profiles/$profileFileName';
        await supabase.storage
            .from('profiles')
            .upload(profileFilePath, profileImage!);
        profileUrl =
            supabase.storage.from('profiles').getPublicUrl(profileFilePath);
        debugPrint('✅ [ClinicApply] Profile uploaded: $profileUrl');
      }

      // --- Frontal/Featured Image Upload ---
      String? frontalUrl = existingFrontalUrl;
      if (frontalImage != null) {
        debugPrint('📡 [ClinicApply] Uploading NEW frontal image...');
        final frontalFileName =
            '${DateTime.now().millisecondsSinceEpoch}_frontal.jpg';
        final safeFilePath = 'offices/frontal_$frontalFileName';

        await supabase.storage
            .from('offices') // Reusing offices bucket for clinic images
            .upload(safeFilePath, frontalImage!);
        frontalUrl =
            supabase.storage.from('offices').getPublicUrl(safeFilePath);
        debugPrint('✅ [ClinicApply] Frontal uploaded: $frontalUrl');
      }

      // --- Build update data ---
      final updateData = <String, dynamic>{
        'address': selectedAddress,
        'latitude': latitude,
        'longitude': longitude,
        'license_url': licenseUrl,
        'permit_url': permitUrl,
        'office_url': officeUrl,
        'profile_url': profileUrl,
        'frontal_image_url': frontalUrl,
      };

      // In edit mode (resubmission), reset status and clear rejection reason
      if (widget.isEditMode) {
        updateData['status'] = 'pending';
        updateData['rejection_reason'] = null;
      }

      debugPrint('📡 [ClinicApply] Updating clinic record in DB...');

      // --- Update clinic record ---
      debugPrint(
          '📡 [ClinicApply] Updating clinic record using resubmission function...');

      // Use the database function for atomic resubmission
      if (widget.isEditMode) {
        final result =
            await supabase.rpc('handle_clinic_resubmission', params: {
          'p_clinic_id': widget.clinicId,
          'p_address': selectedAddress,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_license_url': licenseUrl,
          'p_permit_url': permitUrl,
          'p_office_url': officeUrl,
          'p_profile_url': profileUrl,
          'p_frontal_image_url': frontalUrl,
        });

        debugPrint('✅ [ClinicApply] Resubmission function result: $result');

        if (result['success'] != true) {
          throw Exception(result['error'] ?? 'Resubmission failed');
        }
      } else {
        // Regular update for new applications
        await supabase
            .from('clinics')
            .update(updateData)
            .eq('clinic_id', widget.clinicId);
      }

      debugPrint('✅ [ClinicApply] Database record updated successfully');

      // --- Notify admin of resubmission ---
      if (widget.isEditMode) {
        try {
          debugPrint('📡 [ClinicApply] Notifying admin of resubmission...');
          await supabase.from('notification_queue').insert({
            'type': 'clinic_resubmission',
            'recipient_id': widget.clinicId, // Using clinic_id as reference
            'payload': {
              'clinic_id': widget.clinicId,
              'clinic_name': clinicName ?? 'Unknown Clinic',
              'message': 'Clinic has resubmitted their application for review',
            },
            'processed': false,
          });
          debugPrint('✅ [ClinicApply] Resubmission notification queued');
        } catch (e) {
          debugPrint('⚠️ [ClinicApply] Notification failed (non-critical): $e');
        }
      }

      debugPrint('🎯 [ClinicApply] Process completed successfully');

      // Navigate to success page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DentalSuccess()),
        (route) => false,
      );
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('❌ [ClinicApply] ERROR in submission: $e');

      // Show more specific error messages
      String errorMessage = 'Error submitting application';
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('storage')) {
        errorMessage = 'Error uploading images. Please try again.';
      } else if (e.toString().contains('permission') ||
          e.toString().contains('unauthorized')) {
        errorMessage = 'Permission error. Please try logging in again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else {
        errorMessage = 'Error submitting application: ${e.toString()}';
      }

      _showSnackbar(errorMessage);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectAddress() async {
    debugPrint('🗺️ [ClinicApply] Opening address picker...');
    // Navigate to the address picker screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressPickerScreen(
          onAddressSelected: (address, lat, lng) {
            debugPrint(
                '🗺️ [ClinicApply] Address selected: $address ($lat, $lng)');
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
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Upload License Button - Outlined Style
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage("license"),
                    icon: Icon(
                      licenseImage != null ||
                              (widget.isEditMode && existingLicenseUrl != null)
                          ? Icons.check_circle
                          : Icons.attach_file,
                      color: licenseImage != null ||
                              (widget.isEditMode && existingLicenseUrl != null)
                          ? Colors.green
                          : AppTheme.primaryBlue,
                    ),
                    label: Text(
                      licenseImage != null ||
                              (widget.isEditMode && existingLicenseUrl != null)
                          ? '✓ PRC Credentials Uploaded (Tap to change)'
                          : '📎 Upload PRC Credentials',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: licenseImage != null ||
                                (widget.isEditMode &&
                                    existingLicenseUrl != null)
                            ? Colors.green
                            : AppTheme.primaryBlue,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: licenseImage != null ||
                                (widget.isEditMode &&
                                    existingLicenseUrl != null)
                            ? Colors.green
                            : AppTheme.primaryBlue,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Upload Permit Button - Outlined Style
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage("permit"),
                    icon: Icon(
                      permitImage != null ||
                              (widget.isEditMode && existingPermitUrl != null)
                          ? Icons.check_circle
                          : Icons.attach_file,
                      color: permitImage != null ||
                              (widget.isEditMode && existingPermitUrl != null)
                          ? Colors.green
                          : AppTheme.primaryBlue,
                    ),
                    label: Text(
                      permitImage != null ||
                              (widget.isEditMode && existingPermitUrl != null)
                          ? '✓ DTI Permit Uploaded (Tap to change)'
                          : '📎 Upload DTI Permit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: permitImage != null ||
                                (widget.isEditMode && existingPermitUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: permitImage != null ||
                                (widget.isEditMode && existingPermitUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Upload Office Button - Outlined Style
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage("office"),
                    icon: Icon(
                      officeImage != null ||
                              (widget.isEditMode && existingOfficeUrl != null)
                          ? Icons.check_circle
                          : Icons.attach_file,
                      color: officeImage != null ||
                              (widget.isEditMode && existingOfficeUrl != null)
                          ? Colors.green
                          : const Color(0xFF103D7E),
                    ),
                    label: Text(
                      officeImage != null ||
                              (widget.isEditMode && existingOfficeUrl != null)
                          ? '✓ Workplace Photo Uploaded (Tap to change)'
                          : '📎 Upload Workplace Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: officeImage != null ||
                                (widget.isEditMode && existingOfficeUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: officeImage != null ||
                                (widget.isEditMode && existingOfficeUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Upload Profile/Featured Image Button - Outlined Style
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage("profile"),
                    icon: Icon(
                      profileImage != null ||
                              (widget.isEditMode && existingProfileUrl != null)
                          ? Icons.check_circle
                          : Icons.image_rounded,
                      color: profileImage != null ||
                              (widget.isEditMode && existingProfileUrl != null)
                          ? Colors.green
                          : const Color(0xFF103D7E),
                    ),
                    label: Text(
                      profileImage != null ||
                              (widget.isEditMode && existingProfileUrl != null)
                          ? '✓ Clinic Photo Uploaded (Tap to change)'
                          : '🏥 Upload Clinic Profile Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: profileImage != null ||
                                (widget.isEditMode &&
                                    existingProfileUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: profileImage != null ||
                                (widget.isEditMode &&
                                    existingProfileUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Upload Frontal/Featured Image Button - Outlined Style
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage("frontal"),
                    icon: Icon(
                      frontalImage != null ||
                              (widget.isEditMode && existingFrontalUrl != null)
                          ? Icons.check_circle
                          : Icons.camera_alt_rounded,
                      color: frontalImage != null ||
                              (widget.isEditMode && existingFrontalUrl != null)
                          ? Colors.green
                          : const Color(0xFF103D7E),
                    ),
                    label: Text(
                      frontalImage != null ||
                              (widget.isEditMode && existingFrontalUrl != null)
                          ? '✓ Frontal Page Photo Uploaded (Tap to change)'
                          : '🏢 Upload Frontal/Featured Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: frontalImage != null ||
                                (widget.isEditMode &&
                                    existingFrontalUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: frontalImage != null ||
                                (widget.isEditMode &&
                                    existingFrontalUrl != null)
                            ? Colors.green
                            : const Color(0xFF103D7E),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Submit Button - Large Filled Style
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.isEditMode
                                    ? 'Resubmit Application'
                                    : 'Submit Application',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
