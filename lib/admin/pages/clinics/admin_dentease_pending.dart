import 'package:dentease/admin/pages/clinics/admin_dentease_second.dart';
import 'package:dentease/widgets/adminWidgets/admin_clinic_card.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPendingPage extends StatefulWidget {
  final bool showBackButton;

  const AdminPendingPage({super.key, this.showBackButton = false});

  @override
  State<AdminPendingPage> createState() => _AdminPendingPageState();
}

class _AdminPendingPageState extends State<AdminPendingPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;

  // Professional Blue Medical Theme Colors
  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue
  static const kAccentBlue = Color(0xFF0D2A7A); // Accent Blue
  static const kSuccessGreen = Color(0xFF2E7D32); // Success green
  static const kErrorRed = Color(0xFFD32F2F); // Error red
  static const kBackground = Color(0xFFF8FAFC); // Clean medical background
  static const kTextDark = Color(0xFF0D1B2A); // Primary text
  static const kTextGrey = Color(0xFF5F6C7B); // Secondary text

  @override
  void initState() {
    super.initState();
    debugPrint('📋 [AdminPendingPage] Initializing...');
    debugPrint(
        '📋 [AdminPendingPage] showBackButton: ${widget.showBackButton}');
    // No need to fetch clinics manually - StreamBuilder will handle it
  }

  /// Show rejection reason dialog
  Future<void> _showRejectionDialog(String clinicId, String clinicName) async {
    _rejectionReasonController.clear();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: kErrorRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reject Application',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clinic: $clinicName',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kTextGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please provide a reason for rejection:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rejectionReasonController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter reason...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kPrimaryBlue, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: kTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = _rejectionReasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a rejection reason')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kErrorRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Reject',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _executeStatusUpdate(clinicId, 'rejected', result);
    }
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchClinics() async {
    try {
      final response = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, email, status, created_at')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          clinics = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error fetching clinics');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Execute status update (approve or reject)
  Future<void> _executeStatusUpdate(
      String clinicId, String status, String? rejectionReason) async {
    try {
      // Update clinic status
      await supabase.from('clinics').update({
        'status': status,
        'rejection_reason': rejectionReason,
      }).eq('clinic_id', clinicId);

      // Auto-approve owner dentist if clinic is approved
      if (status == 'approved') {
        await _autoApproveOwnerDentist(clinicId);
      }

      // Auto-reject owner dentist if clinic is rejected
      if (status == 'rejected') {
        await _autoRejectOwnerDentist(clinicId);
      }

      // Send notification to all dentists of this clinic
      await _notifyClinicDentists(clinicId, status, rejectionReason);

      // Remove from list optimistically
      setState(() {
        clinics.removeWhere((clinic) => clinic['clinic_id'] == clinicId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? '✓ Clinic approved successfully'
                  : '✕ Clinic rejected',
            ),
            backgroundColor: status == 'approved' ? kSuccessGreen : kErrorRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error updating status. Please try again.')),
        );
      }
      // Revert optimistic update on error
      _fetchClinics();
    }
  }

  /// Send FCM notification to all dentists of the clinic
  Future<void> _notifyClinicDentists(
      String clinicId, String status, String? rejectionReason) async {
    try {
      final dentists = await supabase
          .from('dentists')
          .select('dentist_id, fcm_token, firstname')
          .eq('clinic_id', clinicId);

      final clinicData = await supabase
          .from('clinics')
          .select('clinic_name')
          .eq('clinic_id', clinicId)
          .maybeSingle();

      final clinicName = clinicData?['clinic_name'] ?? 'Your clinic';

      for (var dentist in dentists) {
        final fcmToken = dentist['fcm_token'];
        if (fcmToken == null || fcmToken.toString().isEmpty) continue;

        String title, body;
        if (status == 'approved') {
          title = '🎉 Clinic Approved!';
          body =
              '$clinicName has been approved. You can now access the dashboard.';
        } else {
          title = '❌ Application Rejected';
          body = rejectionReason != null
              ? 'Reason: $rejectionReason'
              : '$clinicName application was not approved.';
        }

        // TODO: Send FCM notification proper integration
        debugPrint(
            'Sending notification to ${dentist['firstname']}: $title - $body');
      }
    } catch (e) {
      debugPrint('Error sending notifications: $e');
    }
  }

  /// Auto-approve the owner dentist when clinic is approved
  /// Owner dentist = clinic owner who applied, not associate dentists
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
  /// Owner dentist = clinic owner who applied, not associate dentists
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

  Future<void> _onApprove(String clinicId) async {
    // Show confirmation dialog before approving
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Clinic?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text(
            'This will grant the clinic and its dentists access to the platform.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeStatusUpdate(clinicId, 'approved', null);
    }
  }

  Future<void> _onReject(String clinicId, String clinicName) async {
    await _showRejectionDialog(clinicId, clinicName);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: kPrimaryBlue, // Professional blue header
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: widget.showBackButton,
          leading: widget.showBackButton
              ? const BackButton(color: Colors.white)
              : null,
          title: Text(
            "Pending Requests",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('clinics')
              .stream(primaryKey: ['clinic_id']).map((clinics) =>
                  clinics.where((c) => c['status'] == 'pending').toList()
                    ..sort((a, b) => (b['created_at'] as String? ?? '')
                        .compareTo(a['created_at'] as String? ?? ''))),
          builder: (context, snapshot) {
            debugPrint(
                '📡 [AdminPendingPage] StreamBuilder state: ${snapshot.connectionState}');
            debugPrint('📡 [AdminPendingPage] Has data: ${snapshot.hasData}');
            debugPrint('📡 [AdminPendingPage] Has error: ${snapshot.hasError}');
            if (snapshot.hasError) {
              debugPrint('❌ [AdminPendingPage] Error: ${snapshot.error}');
            }

            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              debugPrint('⏳ [AdminPendingPage] Waiting for data...');
              return const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue),
              );
            }

            // Handle error state
            if (snapshot.hasError) {
              debugPrint(
                  '❌ [AdminPendingPage] Stream error: ${snapshot.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: kErrorRed.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading clinics',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        debugPrint('🔄 [AdminPendingPage] Retry triggered');
                        // Trigger rebuild by calling setState
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Get the data
            final clinics = snapshot.data ?? [];
            debugPrint(
                '📊 [AdminPendingPage] Pending clinics count: ${clinics.length}');
            for (int i = 0; i < clinics.length; i++) {
              debugPrint(
                  '🏥 [AdminPendingPage] Clinic $i: ${clinics[i]['clinic_name']} (ID: ${clinics[i]['clinic_id']})');
            }

            // Handle empty state
            if (clinics.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: kSuccessGreen.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All caught up!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No pending clinic applications',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextGrey,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Display the list with real-time updates
            return RefreshIndicator(
              onRefresh: () async {
                // StreamBuilder automatically refreshes, but we can trigger a rebuild
                setState(() {});
              },
              color: kPrimaryBlue,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80, top: 10),
                itemCount: clinics.length,
                itemBuilder: (context, index) {
                  final clinic = clinics[index];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AdminClinicCard(
                      clinicName: clinic['clinic_name'] ?? 'Unknown Clinic',
                      email: clinic['email'] ?? 'No email',
                      status: 'pending',
                      submittedDate: _formatDate(clinic['created_at']),
                      showQuickActions: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdmClinicDashboardPage(
                              clinicId: clinic['clinic_id'],
                              clinicName: clinic['clinic_name'] ?? 'Clinic',
                            ),
                          ),
                        );
                      },
                      onApprove: () => _onApprove(clinic['clinic_id']),
                      onReject: () => _onReject(
                        clinic['clinic_id'],
                        clinic['clinic_name'] ?? 'this clinic',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
