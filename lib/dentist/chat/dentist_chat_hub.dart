import 'dart:async';
import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dentist Chat Hub - New Theme UI
class DentistChatHub extends StatefulWidget {
  final String clinicId;

  const DentistChatHub({
    super.key,
    required this.clinicId,
  });

  @override
  State<DentistChatHub> createState() => _DentistChatHubState();
}

class _DentistChatHubState extends State<DentistChatHub>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();

  // Theme Colors
  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kBackground = Color(0xFFF5F7FA);
  static const kTextDark = Color(0xFF1E293B);
  static const kTextGrey = Color(0xFF64748B);

  late TabController _tabController;

  List<Map<String, dynamic>> patients = [];
  List<Map<String, dynamic>> staff = [];

  // Map UserId -> UnreadCount
  Map<String, int> unreadPatients = {};
  Map<String, int> unreadStaff = {};

  // Map UserId -> ConversationId (to open chat efficiently)
  Map<String, String> conversationIds = {};

  int unreadAdmin = 0;

  bool isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
    // Use Stream for real-time badge updates!
    _subscribeToConversations();
    // Removed inefficient auto-refresh timer - using real-time streams only
  }

  void _subscribeToConversations() {
    // Listen to MY participant rows for unread count changes
    _participantsSubscription = supabase
        .from('conversation_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.clinicId)
        .listen((data) {
          if (mounted) _fetchData();
        });
  }

  @override
  void dispose() {
    _participantsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      // Get actual dentist name first
      String dentistName = 'Clinic';
      try {
        final dentistResponse = await supabase
            .from('dentists')
            .select('firstname, lastname')
            .eq('dentist_id',
                widget.clinicId) // Assuming clinicId is also dentistId
            .maybeSingle();

        if (dentistResponse != null) {
          dentistName =
              '${dentistResponse['firstname'] ?? ''} ${dentistResponse['lastname'] ?? ''}'
                  .trim();
          if (dentistName.isEmpty) dentistName = 'Dentist';
        }
      } catch (e) {
        debugPrint('Error fetching dentist name: $e');
        // Try to get clinic name as fallback
        try {
          final clinicResponse = await supabase
              .from('clinics')
              .select('clinic_name')
              .eq('clinic_id', widget.clinicId)
              .maybeSingle();
          dentistName = clinicResponse?['clinic_name'] ?? 'Clinic';
        } catch (e2) {
          debugPrint('Error fetching clinic name: $e2');
        }
      }

      // 1. Fetch Patients (from Bookings)
      final bookingResponse = await supabase
          .from('bookings')
          .select('patient_id')
          .eq('clinic_id', widget.clinicId);

      final patientIds = bookingResponse
          .map((b) => b['patient_id'] as String)
          .toSet()
          .toList();

      List<Map<String, dynamic>> patientList = [];
      if (patientIds.isNotEmpty) {
        final pRes = await supabase
            .from('patients')
            .select('patient_id, firstname, lastname, email, profile_url')
            .inFilter('patient_id', patientIds);
        patientList = List<Map<String, dynamic>>.from(pRes);
      }

      // 2. Fetch Staff
      final staffRes = await supabase
          .from('staffs')
          .select('staff_id, firstname, lastname, role')
          .eq('clinic_id', widget.clinicId);
      final staffList = List<Map<String, dynamic>>.from(staffRes);

      // 3. Fetch Unread Counts from conversation_participants (New Schema)
      final myParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id, unread_count')
          .eq('user_id', widget.clinicId)
          .eq('is_active', true);

      final activeConvoIds =
          myParticipants.map((p) => p['conversation_id'] as String).toList();

      Map<String, int> pUnread = {};
      Map<String, int> sUnread = {};
      Map<String, String> cIds = {};
      int adminUnreadTotal = 0;

      if (activeConvoIds.isNotEmpty) {
        final allParticipants = await supabase
            .from('conversation_participants')
            .select('conversation_id, user_id, role')
            .inFilter('conversation_id', activeConvoIds);

        for (final myP in myParticipants) {
          final cid = myP['conversation_id'] as String;
          final count = (myP['unread_count'] as int?) ?? 0;

          final others = allParticipants
              .where((p) =>
                  p['conversation_id'] == cid &&
                  p['user_id'] != widget.clinicId)
              .toList();
          if (others.isNotEmpty) {
            final other = others.first;
            final otherId = other['user_id'] as String;
            final otherRole = other['role'] as String?;

            cIds[otherId] = cid;

            if (otherRole == 'admin') {
              adminUnreadTotal += count;
            } else if (patientIds.contains(otherId)) {
              pUnread[otherId] = (pUnread[otherId] ?? 0) + count;
            } else {
              final isStaff = staffList.any((s) => s['staff_id'] == otherId);
              if (isStaff) {
                sUnread[otherId] = (sUnread[otherId] ?? 0) + count;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          patients = patientList;
          staff = staffList;
          unreadPatients = pUnread;
          unreadStaff = sUnread;
          conversationIds = cIds;
          unreadAdmin = adminUnreadTotal;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching chat list: $e");
      if (mounted && isLoading) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPatientUnread = unreadPatients.values.fold(0, (a, b) => a + b);
    final totalStaffUnread = unreadStaff.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            _buildTab('Patients', totalPatientUnread),
            _buildTab('Staff', totalStaffUnread),
            _buildTab('Admin', unreadAdmin),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPatientList(),
                _buildStaffList(),
                _buildAdminList(),
              ],
            ),
    );
  }

  Widget _buildTab(String label, int unreadCount) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    if (patients.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Patients Yet',
        subtitle: 'Patients who book appointments will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: kPrimaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: patients.length,
        itemBuilder: (context, index) {
          final p = patients[index];
          final id = p['patient_id'] as String;
          final name = "${p['firstname'] ?? ''} ${p['lastname'] ?? ''}".trim();
          final email = p['email'] ?? '';
          final profileUrl = p['profile_url'] as String?;
          final unread = unreadPatients[id] ?? 0;

          return _buildChatCard(
            name: name.isEmpty ? 'Unknown Patient' : name,
            subtitle: email,
            unreadCount: unread,
            profileUrl: profileUrl,
            color: kPrimaryBlue,
            onTap: () async {
              final patient = patients[index];
              final pId = patient['patient_id'] as String;
              final pName =
                  '${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''}'
                      .trim();
              final convoId = conversationIds[pId];

              _navigateToChat(
                convoId: convoId,
                otherId: pId,
                otherName: pName,
                otherRole: 'patient',
              );
              _fetchData();
            },
          );
        },
      ),
    );
  }

  Widget _buildStaffList() {
    if (staff.isEmpty) {
      return _buildEmptyState(
        icon: Icons.badge_outlined,
        title: 'No Staff Members',
        subtitle: 'Add staff members to chat with them',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: kPrimaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: staff.length,
        itemBuilder: (context, index) {
          final s = staff[index];
          final id = s['staff_id'] as String;
          final name = "${s['firstname'] ?? ''} ${s['lastname'] ?? ''}".trim();
          final role = s['role'] ?? 'Staff';
          final unread = unreadStaff[id] ?? 0;

          return _buildChatCard(
            name: name.isEmpty ? 'Unknown Staff' : name,
            subtitle: role,
            unreadCount: unread,
            color: Colors.teal,
            onTap: () async {
              final s = staff[index];
              final sId = s['staff_id'] as String;
              final sName =
                  '${s['firstname'] ?? ''} ${s['lastname'] ?? ''}'.trim();
              final convoId = conversationIds[sId];

              _navigateToChat(
                convoId: convoId,
                otherId: sId,
                otherName: sName,
                otherRole: 'staff',
              );
              _fetchData();
            },
          );
        },
      ),
    );
  }

  Widget _buildAdminList() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: kPrimaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildChatCard(
            name: 'Dentease Support',
            subtitle: 'Contact admin for help',
            unreadCount: unreadAdmin,
            color: Colors.orange,
            icon: Icons.support_agent_rounded,
            onTap: () async {
              try {
                // Admin Support - Try multiple approaches to find admin
                Map<String, dynamic>? adminRes;

                // First try: Look for admins table
                try {
                  adminRes = await supabase
                      .from('admins')
                      .select('admin_id, firstname, lastname')
                      .limit(1)
                      .maybeSingle();
                } catch (e) {
                  debugPrint('Admins table not found: $e');
                }

                // Second try: Look for users with admin role
                if (adminRes == null) {
                  try {
                    final userRes = await supabase
                        .from('users')
                        .select('user_id, firstname, lastname, email')
                        .eq('role', 'admin')
                        .limit(1)
                        .maybeSingle();

                    if (userRes != null) {
                      adminRes = {
                        'admin_id': userRes['user_id'],
                        'firstname': userRes['firstname'],
                        'lastname': userRes['lastname'],
                      };
                    }
                  } catch (e) {
                    debugPrint('Users table admin lookup failed: $e');
                  }
                }

                // Third try: Create a default admin conversation
                if (adminRes == null) {
                  // Use a default admin ID for support
                  adminRes = {
                    'admin_id': 'admin-support-default',
                    'firstname': 'Dentease',
                    'lastname': 'Support',
                  };
                }

                final adminId = adminRes['admin_id'] as String;
                final adminName =
                    '${adminRes['firstname'] ?? ''} ${adminRes['lastname'] ?? ''}'
                        .trim();
                final displayAdminName =
                    adminName.isEmpty ? 'Admin Support' : adminName;
                final convoId = conversationIds[adminId];

                await _navigateToChat(
                  convoId: convoId,
                  otherId: adminId,
                  otherName: displayAdminName,
                  otherRole: 'admin',
                );

                // Refresh data after chat
                if (mounted) _fetchData();
              } catch (e) {
                debugPrint('Error opening admin chat: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to open admin chat: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToChat({
    String? convoId,
    required String otherId,
    required String otherName,
    required String otherRole,
  }) async {
    try {
      // Get actual dentist name for better display
      String dentistName = 'Dentist';
      try {
        final dentistResponse = await supabase
            .from('dentists')
            .select('firstname, lastname')
            .eq('dentist_id',
                widget.clinicId) // Assuming clinicId is also dentistId
            .maybeSingle();

        if (dentistResponse != null) {
          dentistName =
              '${dentistResponse['firstname'] ?? ''} ${dentistResponse['lastname'] ?? ''}'
                  .trim();
          if (dentistName.isEmpty) dentistName = 'Dentist';
        }
      } catch (e) {
        debugPrint('Error fetching dentist name: $e');
        // Try to get clinic name as fallback
        try {
          final clinicResponse = await supabase
              .from('clinics')
              .select('clinic_name')
              .eq('clinic_id', widget.clinicId)
              .maybeSingle();
          dentistName = clinicResponse?['clinic_name'] ?? 'Clinic';
        } catch (e2) {
          debugPrint('Error fetching clinic name: $e2');
        }
      }

      // Use null-aware assignment for efficiency
      final activeConvoId = convoId ??
          await _messagingService.getOrCreateDirectConversation(
            user1Id: widget.clinicId,
            user1Role: 'dentist',
            user1Name: dentistName,
            user2Id: otherId,
            user2Role: otherRole,
            user2Name: otherName,
            clinicId: widget.clinicId,
          );

      if (activeConvoId != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: activeConvoId,
              userId: widget.clinicId,
              userRole: 'dentist',
              userName: dentistName,
              otherUserName: otherName,
              otherUserRole: otherRole,
            ),
          ),
        );

        // Refresh data when returning from chat
        if (mounted) _fetchData();
      }
    } catch (e) {
      debugPrint('Error navigating to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildChatCard({
    required String name,
    required String subtitle,
    required int unreadCount,
    required Color color,
    String? profileUrl,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (profileUrl != null && profileUrl.isNotEmpty)
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(profileUrl),
                    backgroundColor: color.withValues(alpha: 0.1),
                  )
                else
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: icon != null
                        ? Icon(icon, color: color, size: 26)
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 20,
                            ),
                          ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          color: kTextGrey,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
