import 'package:dentease/services/messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Staff Availability Management Widget
/// Allows Dentists to toggle staff on/off leave status
/// When staff is on leave, messages route to clinic owner
class StaffAvailabilityWidget extends StatefulWidget {
  final String clinicId;

  const StaffAvailabilityWidget({
    super.key,
    required this.clinicId,
  });

  @override
  State<StaffAvailabilityWidget> createState() =>
      _StaffAvailabilityWidgetState();
}

class _StaffAvailabilityWidgetState extends State<StaffAvailabilityWidget> {
  final MessagingService _messagingService = MessagingService();

  // Theme Colors
  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kBackground = Color(0xFFF5F7FA);
  static const kTextDark = Color(0xFF1E293B);
  static const kTextGrey = Color(0xFF64748B);
  static const kLeaveRed = Color(0xFFE53935);
  static const kActiveGreen = Color(0xFF43A047);

  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;
  final Map<String, bool> _updating = {};

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);

    try {
      final staff =
          await _messagingService.getClinicStaffWithStatus(widget.clinicId);
      if (mounted) {
        setState(() {
          _staff = staff;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading staff: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLeaveStatus(String staffId, bool isOnLeave) async {
    setState(() => _updating[staffId] = true);

    final success =
        await _messagingService.setStaffOnLeaveStatus(staffId, isOnLeave);

    if (mounted) {
      setState(() {
        _updating[staffId] = false;
        if (success) {
          // Update local state
          final index = _staff.indexWhere((s) => s['staff_id'] == staffId);
          if (index != -1) {
            _staff[index]['is_on_leave'] = isOnLeave;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? isOnLeave
                    ? 'Staff marked as on leave. Messages will route to you.'
                    : 'Staff is now available.'
                : 'Failed to update status',
          ),
          backgroundColor:
              success ? (isOnLeave ? kLeaveRed : kActiveGreen) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_outline,
                    color: kPrimaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff Availability',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        'Manage staff leave status',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: kTextGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: kPrimaryBlue),
                  onPressed: _loadStaff,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Info Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'When staff is on leave, patient messages will be routed to you with high priority.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Staff List
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: kPrimaryBlue),
                  ),
                )
              : _staff.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _staff.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final staff = _staff[index];
                        return _buildStaffCard(staff);
                      },
                    ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final staffId = staff['staff_id'] as String;
    final firstName = staff['firstname'] ?? '';
    final lastName = staff['lastname'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final role = staff['role'] ?? 'Staff';
    final isOnLeave = staff['is_on_leave'] as bool? ?? false;
    final isUpdating = _updating[staffId] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isOnLeave ? kLeaveRed.withValues(alpha: 0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: isOnLeave
                ? kLeaveRed.withValues(alpha: 0.1)
                : kActiveGreen.withValues(alpha: 0.1),
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isOnLeave ? kLeaveRed : kActiveGreen,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Unknown Staff' : fullName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOnLeave
                            ? kLeaveRed.withValues(alpha: 0.1)
                            : kActiveGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOnLeave ? Icons.beach_access : Icons.check_circle,
                            size: 12,
                            color: isOnLeave ? kLeaveRed : kActiveGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnLeave ? 'ON LEAVE' : 'AVAILABLE',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isOnLeave ? kLeaveRed : kActiveGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toggle Switch
          isUpdating
              ? const SizedBox(
                  width: 48,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimaryBlue,
                      ),
                    ),
                  ),
                )
              : Switch.adaptive(
                  value: isOnLeave,
                  onChanged: (value) => _toggleLeaveStatus(staffId, value),
                  activeThumbColor: kLeaveRed,
                  activeTrackColor: kLeaveRed.withValues(alpha: 0.3),
                  inactiveThumbColor: kActiveGreen,
                  inactiveTrackColor: kActiveGreen.withValues(alpha: 0.3),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Staff Members',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add staff members to manage their availability',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Standalone page version of the Staff Availability widget
class StaffAvailabilityPage extends StatelessWidget {
  final String clinicId;

  const StaffAvailabilityPage({
    super.key,
    required this.clinicId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          'Staff Availability',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: StaffAvailabilityWidget(clinicId: clinicId),
      ),
    );
  }
}
