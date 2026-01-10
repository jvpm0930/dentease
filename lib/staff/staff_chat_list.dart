import 'dart:async';
import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/staff/staff_chat_patients.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffChatList extends StatefulWidget {
  final String clinicId;
  final String staffId;

  const StaffChatList({
    super.key,
    required this.clinicId,
    required this.staffId,
  });

  @override
  State<StaffChatList> createState() => _StaffChatListState();
}

class _StaffChatListState extends State<StaffChatList> {
  final supabase = Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();

  int unreadDentist = 0;
  int unreadPatients = 0;

  // Cached names
  String _clinicName = 'Clinic';
  String _staffName = 'Staff';

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadNames();
    _fetchUnreadCounts();
    _subscribeToCounts();
  }

  Future<void> _loadNames() async {
    try {
      // Fetch clinic name
      final clinicData = await supabase
          .from('clinics')
          .select('clinic_name')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (clinicData != null && mounted) {
        setState(() {
          _clinicName = clinicData['clinic_name'] ?? 'Clinic';
        });
      }

      // Fetch staff name
      final staffData = await supabase
          .from('staffs')
          .select('firstname, lastname')
          .eq('staff_id', widget.staffId)
          .maybeSingle();

      if (staffData != null && mounted) {
        setState(() {
          _staffName =
              '${staffData['firstname'] ?? ''} ${staffData['lastname'] ?? ''}'
                  .trim();
          if (_staffName.isEmpty) _staffName = 'Staff';
        });
      }
    } catch (e) {
      debugPrint('Error loading names: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToCounts() {
    _subscription = supabase
        .from('conversation_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.staffId)
        .listen((data) {
          if (mounted) _fetchUnreadCounts();
        });
  }

  Future<void> _fetchUnreadCounts() async {
    try {
      // 1. My Conversations
      final myParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id, unread_count')
          .eq('user_id', widget.staffId)
          .eq('is_active', true);

      final activeConvoIds =
          myParticipants.map((p) => p['conversation_id'] as String).toList();

      int dCount = 0;
      int pCount = 0;

      if (activeConvoIds.isNotEmpty) {
        // 2. Find who is in these conversations
        // We need to know if the other person is a Clinic (Dentist) or Patient.
        final allParticipants = await supabase
            .from('conversation_participants')
            .select('conversation_id, role, user_id')
            .inFilter('conversation_id', activeConvoIds);

        for (var myP in myParticipants) {
          final cid = myP['conversation_id'];
          final count = (myP['unread_count'] as int?) ?? 0;
          if (count == 0) continue;

          // Find other
          final others = allParticipants
              .where((p) =>
                  p['conversation_id'] == cid && p['user_id'] != widget.staffId)
              .toList();
          if (others.isNotEmpty) {
            final other = others.first;
            final role = other['role']; // 'dentist', 'patient'
            if (role == 'dentist') {
              dCount += count;
            } else {
              // Assume patient
              pCount += count;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          unreadDentist = dCount;
          unreadPatients = pCount;
        });
      }
    } catch (e) {
      debugPrint("Error fetching staff unread counts: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation, handled by bottom nav
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Messages',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtitle
              Text(
                'Connect with your team and patients',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppTheme.textGrey,
                ),
              ),
              const SizedBox(height: 24),

              // Chat Options
              Expanded(
                child: Column(
                  children: [
                    _buildChatOption(
                      title: 'Chat with Dentist',
                      subtitle: 'Communicate with the clinic dentist',
                      icon: Icons.local_hospital_rounded,
                      color: AppTheme.primaryBlue,
                      badgeCount: unreadDentist,
                      onTap: () async {
                        // Get or Create Conversation with Dentist/Clinic
                        final convoId = await _messagingService
                            .getOrCreateDirectConversation(
                          user1Id: widget.staffId,
                          user1Role: 'staff',
                          user1Name: _staffName,
                          user2Id: widget.clinicId,
                          user2Role: 'dentist',
                          user2Name: _clinicName,
                          clinicId: widget.clinicId,
                        );

                        if (convoId != null && context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                conversationId: convoId,
                                userId: widget.staffId,
                                userRole: 'staff',
                                userName: _staffName,
                                otherUserName: _clinicName,
                                otherUserRole: 'dentist',
                              ),
                            ),
                          );
                          if (mounted) _fetchUnreadCounts();
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildChatOption(
                      title: 'Chat with Patients',
                      subtitle: 'Message patients with appointments',
                      icon: Icons.people_rounded,
                      color: AppTheme.tealAccent,
                      badgeCount: unreadPatients,
                      onTap: () async {
                        if (context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StaffChatPatients(
                                clinicId: widget.clinicId,
                                staffId: widget.staffId,
                              ),
                            ),
                          );
                          if (mounted) _fetchUnreadCounts();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.dividerColor,
            width: 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textGrey.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
