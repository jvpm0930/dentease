import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Patient Chat List - Shows all active conversations with clinics
class PatientChatListPage extends StatefulWidget {
  final String patientId;
  const PatientChatListPage({super.key, required this.patientId});

  @override
  State<PatientChatListPage> createState() => _PatientChatListPageState();
}

class _PatientChatListPageState extends State<PatientChatListPage> {
  final supabase = Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();
  
  // Cached patient name for chat
  String _patientName = '';

  @override
  void initState() {
    super.initState();
    _loadPatientName();
  }

  Future<void> _loadPatientName() async {
    try {
      final patientData = await supabase
          .from('patients')
          .select('firstname, lastname')
          .eq('patient_id', widget.patientId)
          .maybeSingle();
      
      if (patientData != null && mounted) {
        final firstName = patientData['firstname']?.toString().trim() ?? '';
        final lastName = patientData['lastname']?.toString().trim() ?? '';
        setState(() {
          _patientName = '$firstName $lastName'.trim();
          if (_patientName.isEmpty) _patientName = 'Patient';
        });
      }
    } catch (e) {
      debugPrint('Error loading patient name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'My Messages',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _messagingService.streamUserConversations(widget.patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue));
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: AppTheme.textGrey),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppTheme.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: _getClinicInfo(conv),
                builder: (context, clinicSnapshot) {
                  if (clinicSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return _buildLoadingCard();
                  }

                  final clinicInfo = clinicSnapshot.data ?? {};
                  final clinicName = clinicInfo['clinic_name'] ?? 'Clinic';
                  final clinicImage = clinicInfo['clinic_image'] as String?;

                  // If we still have a generic name, try to refresh the conversation
                  if (clinicName == 'Clinic' || clinicName.isEmpty) {
                    // Refresh display names in background (don't await)
                    _messagingService.refreshConversationDisplayNames(
                        conv['conversation_id']);
                  }

                  final lastMsg =
                      conv['last_message_preview'] ?? 'Start chatting...';
                  final unread = (conv['unread_count'] as int?) ?? 0;
                  final timestamp = conv['last_message_at'] != null
                      ? DateTime.parse(conv['last_message_at']).toLocal()
                      : DateTime.now();

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 0,
                    color: AppTheme.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.dividerColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppTheme.primaryBlue.withValues(alpha: 0.1),
                        backgroundImage:
                            clinicImage != null && clinicImage.isNotEmpty
                                ? NetworkImage(clinicImage)
                                : null,
                        child: clinicImage == null || clinicImage.isEmpty
                            ? const Icon(Icons.local_hospital_rounded,
                                color: AppTheme.primaryBlue, size: 28)
                            : null,
                      ),
                      title: Text(
                        clinicName,
                        style: GoogleFonts.poppins(
                          fontWeight:
                              unread > 0 ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: unread > 0
                              ? AppTheme.textDark
                              : AppTheme.textGrey,
                          fontWeight:
                              unread > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: unread > 0
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textGrey,
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      onTap: () async {
                        // Get the actual participant info for proper role assignment
                        final participants = await supabase
                            .from('conversation_participants')
                            .select('user_id, role, display_name')
                            .eq('conversation_id', conv['conversation_id'])
                            .neq('user_id', widget.patientId);

                        String otherUserRole = 'dentist'; // default
                        if (participants.isNotEmpty) {
                          // Prefer dentist, then staff
                          final dentist = participants
                              .where((p) => p['role'] == 'dentist')
                              .firstOrNull;
                          final staff = participants
                              .where((p) => p['role'] == 'staff')
                              .firstOrNull;

                          if (dentist != null) {
                            otherUserRole = 'dentist';
                          } else if (staff != null) {
                            otherUserRole = 'staff';
                          }
                        }

                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: conv['conversation_id'],
                              userId: widget.patientId,
                              userRole: 'patient',
                              userName: _patientName.isNotEmpty ? _patientName : 'Patient',
                              otherUserName: clinicName,
                              otherUserRole: otherUserRole,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getClinicInfo(
      Map<String, dynamic> conversation) async {
    try {
      // Get clinic ID from conversation
      final clinicId = conversation['clinic_id'] as String?;
      if (clinicId == null) return {};

      debugPrint(
          'Getting clinic info for conversation: ${conversation['conversation_id']}');
      debugPrint('Clinic ID: $clinicId');

      // First, get the clinic name for context
      String clinicName = '';
      String? clinicImage;
      final clinicResponse = await supabase
          .from('clinics')
          .select('clinic_name, profile_url')
          .eq('clinic_id', clinicId)
          .maybeSingle();

      if (clinicResponse != null) {
        clinicName = clinicResponse['clinic_name'] ?? '';
        clinicImage = clinicResponse['profile_url'];
      }

      // Get participants for this conversation
      final participants = await supabase
          .from('conversation_participants')
          .select('user_id, role, display_name')
          .eq('conversation_id', conversation['conversation_id'])
          .neq('user_id', widget.patientId);

      debugPrint('Participants found: ${participants.length}');
      for (var p in participants) {
        debugPrint(
            'Participant: user_id=${p['user_id']}, role=${p['role']}, display_name=${p['display_name']}');
      }

      // Look for dentist participant first
      final dentistParticipant =
          participants.where((p) => p['role'] == 'dentist').firstOrNull;

      if (dentistParticipant != null) {
        final dentistUserId = dentistParticipant['user_id'] as String;
        debugPrint('Looking up dentist with user_id: $dentistUserId');

        // The user_id in conversation_participants is the auth user id (id column in dentists table)
        // Try querying by 'id' column first
        var dentistResponse = await supabase
            .from('dentists')
            .select('firstname, lastname, profile_url')
            .eq('id', dentistUserId)
            .maybeSingle();

        // If not found, try dentist_id column
        if (dentistResponse == null) {
          debugPrint('Not found by id, trying dentist_id');
          dentistResponse = await supabase
              .from('dentists')
              .select('firstname, lastname, profile_url')
              .eq('dentist_id', dentistUserId)
              .maybeSingle();
        }

        debugPrint('Dentist response: $dentistResponse');

        if (dentistResponse != null) {
          final firstName =
              dentistResponse['firstname']?.toString().trim() ?? '';
          final lastName = dentistResponse['lastname']?.toString().trim() ?? '';
          final dentistName = '$firstName $lastName'.trim();

          debugPrint('Dentist name resolved: $dentistName');

          if (dentistName.isNotEmpty && dentistName != ' ') {
            // Format: "Dr. FirstName LastName • ClinicName" or just "Dr. FirstName LastName"
            String displayName = 'Dr. $dentistName';
            if (clinicName.isNotEmpty) {
              displayName = '$displayName • $clinicName';
            }

            // Update the display name in the database for future use
            _messagingService.updateParticipantDisplayName(
                conversation['conversation_id'],
                dentistUserId,
                'Dr. $dentistName');

            return {
              'clinic_name': displayName,
              'clinic_image': dentistResponse['profile_url'] ?? clinicImage,
            };
          }
        }

        // If dentist name couldn't be fetched, use clinic name with role indicator
        if (clinicName.isNotEmpty) {
          return {
            'clinic_name': 'Dr. ($clinicName)',
            'clinic_image': clinicImage,
          };
        }
      }

      // Look for staff participant if no dentist found
      final staffParticipant =
          participants.where((p) => p['role'] == 'staff').firstOrNull;

      if (staffParticipant != null) {
        final staffUserId = staffParticipant['user_id'] as String;
        debugPrint('Looking up staff with user_id: $staffUserId');

        // The user_id in conversation_participants is the auth user id (id column in staffs table)
        // Try querying by 'id' column first
        var staffResponse = await supabase
            .from('staffs')
            .select('firstname, lastname, profile_url')
            .eq('id', staffUserId)
            .maybeSingle();

        // If not found, try staff_id column
        if (staffResponse == null) {
          debugPrint('Not found by id, trying staff_id');
          staffResponse = await supabase
              .from('staffs')
              .select('firstname, lastname, profile_url')
              .eq('staff_id', staffUserId)
              .maybeSingle();
        }

        debugPrint('Staff response: $staffResponse');

        if (staffResponse != null) {
          final firstName = staffResponse['firstname']?.toString().trim() ?? '';
          final lastName = staffResponse['lastname']?.toString().trim() ?? '';
          final staffName = '$firstName $lastName'.trim();

          debugPrint('Staff name resolved: $staffName');

          if (staffName.isNotEmpty && staffName != ' ') {
            // Format: "StaffName • ClinicName" to help patient identify which clinic
            String displayName = staffName;
            if (clinicName.isNotEmpty) {
              displayName = '$staffName • $clinicName';
            }

            // Update the display name in the database for future use
            _messagingService.updateParticipantDisplayName(
                conversation['conversation_id'], staffUserId, staffName);

            return {
              'clinic_name': displayName,
              'clinic_image': staffResponse['profile_url'] ?? clinicImage,
            };
          }
        }

        // If staff name couldn't be fetched, use clinic name
        if (clinicName.isNotEmpty) {
          return {
            'clinic_name': 'Staff ($clinicName)',
            'clinic_image': clinicImage,
          };
        }
      }

      // Fallback: Just use clinic name if no specific participant found
      if (clinicName.isNotEmpty) {
        // Try to get the dentist name for this clinic as a last resort
        final clinicDentistResponse = await supabase
            .from('dentists')
            .select('firstname, lastname, profile_url')
            .eq('clinic_id', clinicId)
            .limit(1)
            .maybeSingle();

        if (clinicDentistResponse != null) {
          final firstName =
              clinicDentistResponse['firstname']?.toString().trim() ?? '';
          final lastName =
              clinicDentistResponse['lastname']?.toString().trim() ?? '';
          final dentistName = '$firstName $lastName'.trim();

          if (dentistName.isNotEmpty && dentistName != ' ') {
            return {
              'clinic_name': 'Dr. $dentistName • $clinicName',
              'clinic_image':
                  clinicDentistResponse['profile_url'] ?? clinicImage,
            };
          }
        }

        return {
          'clinic_name': clinicName,
          'clinic_image': clinicImage,
        };
      }

      return {};
    } catch (e) {
      debugPrint('Error fetching clinic info: $e');
      return {};
    }
  }

  Widget _buildLoadingCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.dividerColor,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: Container(
          height: 16,
          width: 100,
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          height: 12,
          width: 150,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
}
