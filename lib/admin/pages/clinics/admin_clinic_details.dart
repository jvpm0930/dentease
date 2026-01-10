import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicDetailsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicDetailsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicDetailsPage> createState() => _AdmClinicDetailsPageState();
}

class _AdmClinicDetailsPageState extends State<AdmClinicDetailsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _rejectionReasonController =
      TextEditingController();

  Map<String, dynamic>? clinicDetails;
  bool isLoading = true;
  String selectedStatus = 'pending';

  static const kPrimary = Color(0xFF1134A6);

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchClinicDetails() async {
    debugPrint(
        '🔄 [AdminClinicDetails] Starting to fetch clinic details for clinicId: ${widget.clinicId}');

    try {
      // Get current user info for debugging
      final currentUser = supabase.auth.currentUser;
      debugPrint('👤 [AdminClinicDetails] Current user ID: ${currentUser?.id}');
      debugPrint(
          '👤 [AdminClinicDetails] Current user email: ${currentUser?.email}');

      debugPrint(
          '📡 [AdminClinicDetails] Executing query for clinic: ${widget.clinicId}');

      final response = await supabase
          .from('clinics')
          .select(
            'clinic_name, email, info, license_url, office_url, permit_url, latitude, longitude, address, status, rejection_reason, is_featured, note',
          )
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      debugPrint('✅ [AdminClinicDetails] Query completed');
      debugPrint('📊 [AdminClinicDetails] Response: $response');

      if (response == null) {
        debugPrint(
            '❌ [AdminClinicDetails] No clinic found with ID: ${widget.clinicId}');
        throw Exception('Clinic details not found for ID: ${widget.clinicId}');
      }

      debugPrint(
          '✅ [AdminClinicDetails] Clinic found: ${response['clinic_name']}');
      debugPrint('📋 [AdminClinicDetails] Status: ${response['status']}');

      if (mounted) {
        setState(() {
          clinicDetails = response;
          selectedStatus = response['status'] ?? 'pending';
          // Load existing note if available
          _noteController.text = response['note'] ?? '';
          _rejectionReasonController.text = response['rejection_reason'] ?? '';
          isLoading = false;
        });
        debugPrint('🎯 [AdminClinicDetails] State updated successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AdminClinicDetails] Error fetching clinic details: $e');
      debugPrint('📚 [AdminClinicDetails] Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching clinic details: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isLoading = false);
      }
    }
  }

  /// Handles the status update flow with rejection reason dialog
  Future<void> _handleStatusUpdate() async {
    final currentStatus = clinicDetails?['status'] ?? 'pending';

    // If status hasn't changed, do nothing
    if (selectedStatus == currentStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status is already set to this value')),
      );
      return;
    }

    // If rejecting, show dialog for reason
    if (selectedStatus == 'rejected') {
      _showRejectionDialog();
    } else {
      // For approved or pending, update immediately (clear rejection_reason)
      await _executeStatusUpdate(selectedStatus, null);
    }
  }

  /// Shows a dialog to collect rejection reason
  void _showRejectionDialog() {
    _rejectionReasonController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Reject Clinic'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for rejecting this clinic application:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rejectionReasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kPrimary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = _rejectionReasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a rejection reason')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                await _executeStatusUpdate('rejected', reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm Rejection'),
            ),
          ],
        );
      },
    );
  }

  /// Executes the actual status update to Supabase
  Future<void> _executeStatusUpdate(
      String status, String? rejectionReason) async {
    try {
      await supabase.from('clinics').update({
        'status': status,
        'rejection_reason': rejectionReason,
      }).eq('clinic_id', widget.clinicId);

      // Auto-approve owner dentist if clinic is approved
      if (status == 'approved') {
        await _autoApproveOwnerDentist(widget.clinicId);
      }

      // Auto-reject owner dentist if clinic is rejected
      if (status == 'rejected') {
        await _autoRejectOwnerDentist(widget.clinicId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${status.toUpperCase()}'),
            backgroundColor: status == 'approved'
                ? Colors.green.shade600
                : Colors.red.shade600,
          ),
        );
        // Navigate back to refresh the list
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating status')),
        );
      }
    }
  }

  /// Auto-approve the owner dentist when clinic is approved
  Future<void> _autoApproveOwnerDentist(String clinicId) async {
    try {
      // Fetch clinic's owner_id
      final clinic = await supabase
          .from('clinics')
          .select('owner_id')
          .eq('clinic_id', clinicId)
          .maybeSingle();

      if (clinic != null && clinic['owner_id'] != null) {
        final ownerId = clinic['owner_id'];

        // Auto-approve the owner dentist
        await supabase
            .from('dentists')
            .update({'status': 'approved'}).eq('dentist_id', ownerId);

        debugPrint(
            '✅ Auto-approved owner dentist: $ownerId for clinic: $clinicId');
      } else {
        debugPrint('⚠️ No owner_id found for clinic: $clinicId');
      }
    } catch (e) {
      debugPrint('❌ Error auto-approving owner dentist: $e');
      // Don't throw - clinic approval should still succeed even if owner approval fails
    }
  }

  /// Auto-reject the owner dentist when clinic is rejected
  Future<void> _autoRejectOwnerDentist(String clinicId) async {
    try {
      // Fetch clinic's owner_id
      final clinic = await supabase
          .from('clinics')
          .select('owner_id')
          .eq('clinic_id', clinicId)
          .maybeSingle();

      if (clinic != null && clinic['owner_id'] != null) {
        final ownerId = clinic['owner_id'];

        // Auto-reject the owner dentist
        await supabase
            .from('dentists')
            .update({'status': 'rejected'}).eq('dentist_id', ownerId);

        debugPrint(
            '✅ Auto-rejected owner dentist: $ownerId for clinic: $clinicId');
      } else {
        debugPrint('⚠️ No owner_id found for clinic: $clinicId');
      }
    } catch (e) {
      debugPrint('❌ Error auto-rejecting owner dentist: $e');
      // Don't throw - clinic rejection should still succeed even if owner rejection fails
    }
  }

  Future<void> _toggleFeatured(bool value) async {
    try {
      await supabase
          .from('clinics')
          .update({'is_featured': value}).eq('clinic_id', widget.clinicId);

      setState(() {
        clinicDetails!['is_featured'] = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? '⭐ Clinic featured!' : 'Removed from featured',
            ),
            backgroundColor:
                value ? Colors.amber.shade700 : Colors.grey.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating featured status')),
        );
      }
    }
  }

  Future<void> _updateNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty')),
      );
      return;
    }

    try {
      await supabase
          .from('clinics')
          .update({'note': noteText}).eq('clinic_id', widget.clinicId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear the note field after successful send
        _noteController.clear();
      }
    } catch (e) {
      debugPrint('❌ [AdminClinicDetails] Error sending note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Clinic Details',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0D1B2A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1134A6),
                strokeWidth: 2,
              ),
            )
          : clinicDetails == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No details found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Name + Status chip
                      _ModernSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clinicDetails!['clinic_name'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D1B2A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                        clinicDetails!['status'] ?? 'pending'),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    (clinicDetails!['status'] ?? 'pending')
                                        .toString()
                                        .toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Current Status',
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Status update area
                      _ModernSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ModernSectionTitle(
                              icon: Icons.admin_panel_settings_rounded,
                              title: 'Update Status',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      value: selectedStatus,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'pending',
                                          child: Text('Pending'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'rejected',
                                          child: Text('Rejected'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'approved',
                                          child: Text('Approved'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => selectedStatus = val);
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Select new status',
                                        prefixIcon: Icon(
                                          Icons.flag_rounded,
                                          color: Color(0xFF1134A6),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1134A6),
                                        Color(0xFF0F3086),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1134A6)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _handleStatusUpdate,
                                    icon: const Icon(Icons.save_rounded,
                                        size: 18),
                                    label: const Text('Update'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Notes
                      _ModernSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ModernSectionTitle(
                              icon: Icons.note_alt_rounded,
                              title: 'Admin Note to Clinic',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _noteController,
                                      minLines: 3,
                                      maxLines: 6,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Write a note or reason for status changes...',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1134A6),
                                        Color(0xFF0F3086),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1134A6)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _updateNote,
                                    icon: const Icon(Icons.send_rounded,
                                        size: 18),
                                    label: const Text('Send'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Featured Clinic Toggle
                      _ModernSectionCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.star_rounded,
                                color: Colors.amber.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Feature this Clinic',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0D1B2A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Featured clinics appear first for patients',
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: clinicDetails!['is_featured'] ?? false,
                              onChanged: _toggleFeatured,
                              activeColor: Colors.amber.shade700,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Contact + Info
                      _ModernSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ModernSectionTitle(
                              icon: Icons.info_outline_rounded,
                              title: 'Clinic Information',
                            ),
                            const SizedBox(height: 16),
                            _ModernInfoRow(
                              icon: Icons.email_rounded,
                              label: 'Email',
                              value: clinicDetails!['email'] ??
                                  'No email provided',
                            ),
                            const SizedBox(height: 12),
                            _ModernInfoRow(
                              icon: Icons.location_on_rounded,
                              label: 'Address',
                              value: clinicDetails!['address'] ??
                                  'No address provided',
                              multiLine: true,
                            ),
                            const SizedBox(height: 12),
                            _ModernInfoRow(
                              icon: Icons.description_rounded,
                              label: 'Info',
                              value:
                                  clinicDetails!['info'] ?? 'No info provided',
                              multiLine: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Map
                      if (clinicDetails!['latitude'] != null &&
                          clinicDetails!['longitude'] != null)
                        _ModernSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ModernSectionTitle(
                                icon: Icons.map_rounded,
                                title: 'Location',
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  height: 200,
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        (clinicDetails!['latitude'] as num)
                                            .toDouble(),
                                        (clinicDetails!['longitude'] as num)
                                            .toDouble(),
                                      ),
                                      zoom: 15,
                                    ),
                                    markers: {
                                      Marker(
                                        markerId:
                                            const MarkerId('clinicLocation'),
                                        position: LatLng(
                                          (clinicDetails!['latitude'] as num)
                                              .toDouble(),
                                          (clinicDetails!['longitude'] as num)
                                              .toDouble(),
                                        ),
                                      ),
                                    },
                                    myLocationButtonEnabled: false,
                                    zoomControlsEnabled: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Credentials
                      _ModernSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ModernSectionTitle(
                              icon: Icons.verified_user_rounded,
                              title: 'Credentials',
                            ),
                            const SizedBox(height: 16),
                            _ModernImageTile(
                              title: 'PRC Credentials',
                              url: clinicDetails!['license_url'],
                            ),
                            const SizedBox(height: 16),
                            _ModernImageTile(
                              title: 'DTI Permit',
                              url: clinicDetails!['permit_url'],
                            ),
                            const SizedBox(height: 16),
                            _ModernImageTile(
                              title: 'Workplace',
                              url: clinicDetails!['office_url'],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}

class _ModernSectionCard extends StatelessWidget {
  final Widget child;
  const _ModernSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ModernSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _ModernSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1134A6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1134A6),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: const Color(0xFF0D1B2A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ModernInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;

  const _ModernInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1134A6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1134A6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernImageTile extends StatelessWidget {
  final String title;
  final String? url;

  const _ModernImageTile({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0D1B2A),
          ),
        ),
        const SizedBox(height: 12),
        if (url != null && (url as String).isNotEmpty)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImage(imageUrl: url!),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    url!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_rounded,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No image available',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
