import 'package:dentease/admin/pages/clinics/admin_clinic_details.dart';
import 'package:dentease/admin/pages/clinics/admin_dentease_second.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Rejected Clinics List Page
/// Shows all clinics with status='rejected' with option to reconsider
class AdminRejectedList extends StatefulWidget {
  const AdminRejectedList({super.key});

  @override
  State<AdminRejectedList> createState() => _AdminRejectedListState();
}

class _AdminRejectedListState extends State<AdminRejectedList> {
  final supabase = Supabase.instance.client;

  static const kPrimaryBlue = Color(0xFF1134A6);
  static const kSuccessGreen = Color(0xFF2E7D32);
  static const kErrorRed = Color(0xFFD32F2F);
  static const kWarningOrange = Color(0xFFF9A825);
  static const kBackground = Color(0xFFF8FAFC);

  void _showSnackbar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Reconsider a rejected clinic - set back to pending
  Future<void> _onReconsider(String clinicId, String clinicName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.refresh_rounded, color: kWarningOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reconsider Application?',
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
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will move the clinic back to "Pending" status for re-review. The clinic owner will be able to see their application is being reconsidered.',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              'Reconsider',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kWarningOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeReconsider(clinicId);
    }
  }

  /// Execute the reconsider action - update status to pending
  Future<void> _executeReconsider(String clinicId) async {
    debugPrint(
        '🔄 [AdminRejectedList] Executing reconsider for clinicId: $clinicId');
    try {
      await supabase.from('clinics').update({
        'status': 'pending',
        'rejection_reason': null, // Clear rejection reason
      }).eq('clinic_id', clinicId);

      debugPrint('✅ [AdminRejectedList] Reconsider successful');
      if (mounted) {
        _showSnackbar(
          '✓ Clinic moved back to Pending for review',
          backgroundColor: kSuccessGreen,
        );
      }
    } catch (e) {
      debugPrint('❌ [AdminRejectedList] Error reconsidering clinic: $e');
      if (mounted) {
        _showSnackbar(
          'Error updating status. Please try again.',
          backgroundColor: kErrorRed,
        );
      }
    }
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: true,
          leading: const BackButton(color: Colors.black),
          title: Text(
            "Rejected Clinics",
            style: GoogleFonts.poppins(
              color: const Color(0xFF102A43),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('clinics')
              .stream(primaryKey: ['clinic_id']).map((clinics) =>
                  clinics.where((c) => c['status'] == 'rejected').toList()
                    ..sort((a, b) => (b['created_at'] as String? ?? '')
                        .compareTo(a['created_at'] as String? ?? ''))),
          builder: (context, snapshot) {
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue),
              );
            }

            // Handle error state
            if (snapshot.hasError) {
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
                        color: const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
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
                      'No Rejected Clinics',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All applications have been processed',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Display the list with real-time updates
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: kPrimaryBlue,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80, top: 10),
                itemCount: clinics.length,
                itemBuilder: (context, index) {
                  final clinic = clinics[index];
                  return _buildRejectedClinicCard(clinic);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build a rejected clinic card with Reconsider button
  Widget _buildRejectedClinicCard(Map<String, dynamic> clinic) {
    final clinicId = clinic['clinic_id'] ?? '';
    final clinicName = clinic['clinic_name'] ?? 'Unknown Clinic';
    final email = clinic['email'] ?? 'No email';
    final rejectionReason = clinic['rejection_reason'] ?? 'No reason provided';
    final createdAt = _formatDate(clinic['created_at']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clinic name and status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        clinicName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF102A43),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kErrorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kErrorRed, width: 1.5),
                      ),
                      child: Text(
                        'REJECTED',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kErrorRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Email
                Row(
                  children: [
                    Icon(Icons.email_outlined,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Submitted: $createdAt',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],

                // Rejection reason
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kErrorRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: kErrorRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rejection Reason:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kErrorRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rejectionReason,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action footer with Reconsider button
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE5E5EA), width: 1),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // View Details button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdmClinicDetailsPage(
                            clinicId: clinicId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(
                      'View',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryBlue,
                      side: const BorderSide(color: kPrimaryBlue, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Reconsider button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onReconsider(clinicId, clinicName),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Reconsider',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kWarningOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
