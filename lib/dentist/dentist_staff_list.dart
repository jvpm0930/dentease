import 'package:dentease/dentist/dentist_add_staff.dart';
import 'package:dentease/dentist/edit_staff_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentStaffListPage extends StatefulWidget {
  final String clinicId;

  const DentStaffListPage({super.key, required this.clinicId});

  @override
  _DentStaffListPageState createState() => _DentStaffListPageState();
}

class _DentStaffListPageState extends State<DentStaffListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> staffs = [];
  bool isLoading = true;

  // Professional Blue Medical Theme Colors
  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue
  static const kTextDark = Color(0xFF0D1B2A); // Primary text
  static const kTextGrey = Color(0xFF5F6C7B); // Secondary text

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      final response = await supabase
          .from('staffs')
          .select('staff_id, firstname, lastname, email, phone, is_on_leave')
          .eq('clinic_id', widget.clinicId);

      setState(() {
        staffs = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching staff: $e')),
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

  Future<void> _toggleStaffLeave(Map<String, dynamic> staff) async {
    final staffName =
        "${staff['firstname'] ?? ''} ${staff['lastname'] ?? ''}".trim();
    final isCurrentlyOnLeave = staff['is_on_leave'] ?? false;
    final newLeaveStatus = !isCurrentlyOnLeave;

    try {
      // Update staff leave status in database
      await supabase.from('staffs').update({'is_on_leave': newLeaveStatus}).eq(
          'staff_id', staff['staff_id']);

      // Update local state
      setState(() {
        staff['is_on_leave'] = newLeaveStatus;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newLeaveStatus
                ? '$staffName is now on leave'
                : '$staffName is now available'),
            backgroundColor: newLeaveStatus ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating staff status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _navigateToAddStaff() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DentAddStaff(clinicId: widget.clinicId),
      ),
    );

    if (result == true) {
      _fetchStaff();
    }
  }

  Future<void> _navigateToEditStaff(Map<String, dynamic> staff) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditStaffPage(
          staffId: staff['staff_id'],
          clinicId: widget.clinicId,
          staffData: staff,
        ),
      ),
    );

    if (result == true) {
      _fetchStaff();
    }
  }

  Future<void> _deleteStaff(Map<String, dynamic> staff) async {
    final staffName =
        "${staff['firstname'] ?? ''} ${staff['lastname'] ?? ''}".trim();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Remove Staff Member'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to remove $staffName from your clinic?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The staff member will lose access to the clinic.',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: kTextGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the staff member from the database
      await supabase.from('staffs').delete().eq('staff_id', staff['staff_id']);

      // Remove from local list
      setState(() {
        staffs.removeWhere((s) => s['staff_id'] == staff['staff_id']);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$staffName has been removed successfully'),
            backgroundColor: const Color(0xFF00BFA5),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing staff member: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Clean medical background
        appBar: AppBar(
          backgroundColor: kPrimaryBlue, // Professional blue header
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Staff Members',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: const BackButton(color: Colors.white),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _navigateToAddStaff,
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text("Add Staff",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue))
            : RefreshIndicator(
                onRefresh: _fetchStaff,
                color: kPrimaryBlue,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                  children: [
                    if (staffs.isEmpty)
                      _buildEmptyState()
                    else
                      ...staffs.map((staff) => _StaffCard(
                            staff: staff,
                            onTap: () => _navigateToEditStaff(staff),
                            onDelete: () => _deleteStaff(staff),
                            onToggleLeave: () => _toggleStaffLeave(staff),
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No Staff Members",
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
          ),
          const SizedBox(height: 8),
          Text(
            "Add staff members to help manage your clinic.",
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(color: kTextGrey),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleLeave;

  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kTextDark = Color(0xFF1E293B);
  static const kTextGrey = Color(0xFF64748B);

  const _StaffCard({
    required this.staff,
    required this.onTap,
    required this.onDelete,
    required this.onToggleLeave,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        "${staff['firstname'] ?? ''} ${staff['lastname'] ?? ''}".trim();
    final email = staff['email'] ?? 'No Email';
    final phone = staff['phone'] ?? 'No Phone';
    final isOnLeave = staff['is_on_leave'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isOnLeave
                        ? Colors.grey.withValues(alpha: 0.2)
                        : kPrimaryBlue.withValues(alpha: 0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: isOnLeave ? Colors.grey : kPrimaryBlue,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isOnLeave ? kTextGrey : kTextDark,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOnLeave
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOnLeave ? 'On Leave' : 'Available',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOnLeave
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email_outlined,
                                size: 14, color: kTextGrey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                style: GoogleFonts.roboto(
                                  color: kTextGrey,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 14, color: kTextGrey),
                            const SizedBox(width: 6),
                            Text(
                              phone,
                              style: GoogleFonts.roboto(
                                color: kTextGrey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onTap();
                      } else if (value == 'delete') {
                        onDelete();
                      } else if (value == 'toggle_leave') {
                        onToggleLeave();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle_leave',
                        child: Row(
                          children: [
                            Icon(
                              isOnLeave
                                  ? Icons.work_outline
                                  : Icons.time_to_leave_outlined,
                              size: 18,
                              color: isOnLeave
                                  ? Colors.green.shade600
                                  : Colors.orange.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnLeave ? 'Mark Available' : 'Mark On Leave',
                              style: GoogleFonts.poppins(
                                color: isOnLeave
                                    ? Colors.green.shade600
                                    : Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: kPrimaryBlue),
                            const SizedBox(width: 8),
                            Text(
                              'Edit',
                              style: GoogleFonts.poppins(color: kTextDark),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Remove',
                              style: GoogleFonts.poppins(
                                  color: Colors.red.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                    icon:
                        const Icon(Icons.more_vert_rounded, color: Colors.grey),
                  ),
                ],
              ),

              // Quick Toggle Button
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 1,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    isOnLeave ? Icons.time_to_leave : Icons.work,
                    size: 16,
                    color: isOnLeave
                        ? Colors.orange.shade600
                        : Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOnLeave
                        ? 'Staff is currently on leave'
                        : 'Staff is available for work',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: kTextGrey,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onToggleLeave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOnLeave
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOnLeave
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Text(
                        isOnLeave ? 'Mark Available' : 'Mark On Leave',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOnLeave
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
