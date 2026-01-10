import 'dart:async';
import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffChatPatients extends StatefulWidget {
  final String clinicId;
  final String staffId;

  const StaffChatPatients({
    super.key,
    required this.clinicId,
    required this.staffId,
  });

  @override
  State<StaffChatPatients> createState() => _StaffChatPatientsState();
}

class _StaffChatPatientsState extends State<StaffChatPatients> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();

  List<Map<String, dynamic>> patients = [];
  Map<String, int> unreadCounts = {};
  Map<String, String> conversationIds = {};
  String _staffName = 'Staff';

  bool isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadStaffName();
    _loadPatients();
    _subscribeToConversations();
  }

  Future<void> _loadStaffName() async {
    try {
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
      debugPrint('Error loading staff name: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToConversations() {
    _subscription = supabase
        .from('conversation_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.staffId)
        .listen((data) {
          if (mounted) _loadPatients(); // simplest way to sync badges
        });
  }

  Future<void> _loadPatients() async {
    try {
      // 1. Get patients who have appointments at this clinic
      final response = await supabase
          .from('bookings')
          .select(
              'patient_id, patients(patient_id, firstname, lastname, email)')
          .eq('clinic_id', widget.clinicId)
          .or('status.eq.approved,status.eq.completed');

      // Remove duplicates and get unique patients
      final Map<String, Map<String, dynamic>> uniquePatients = {};
      final List<String> patientIds = [];

      for (final booking in response) {
        final patient = booking['patients'];
        if (patient != null) {
          final pid = patient['patient_id'] as String;
          if (!uniquePatients.containsKey(pid)) {
            uniquePatients[pid] = patient;
            patientIds.add(pid);
          }
        }
      }

      // 2. Fetch Unread Counts from conversation_participants
      // Get my active conversations
      final myParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id, unread_count')
          .eq('user_id', widget.staffId)
          .eq('is_active', true);

      final activeConvoIds =
          myParticipants.map((p) => p['conversation_id'] as String).toList();

      Map<String, int> uCounts = {};
      Map<String, String> cIds = {};

      if (activeConvoIds.isNotEmpty) {
        final allParticipants = await supabase
            .from('conversation_participants')
            .select('conversation_id, role, user_id')
            .inFilter('conversation_id', activeConvoIds);

        for (var myP in myParticipants) {
          final cid = myP['conversation_id'];
          final count = (myP['unread_count'] as int?) ?? 0;

          // Find partner (should correspond to a patient in our list, or a cached one)
          final others = allParticipants
              .where((p) =>
                  p['conversation_id'] == cid && p['user_id'] != widget.staffId)
              .toList();
          if (others.isNotEmpty) {
            final other = others.first;
            final otherId = other['user_id'] as String;
            if (uniquePatients.containsKey(otherId) ||
                patientIds.contains(otherId)) {
              uCounts[otherId] = (uCounts[otherId] ?? 0) + count;
              cIds[otherId] = cid as String;
            }
          }
        }
      }

      setState(() {
        patients = uniquePatients.values.toList();
        unreadCounts = uCounts;
        conversationIds = cIds;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading patients: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Chat with Patients',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
            : patients.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      return _buildPatientCard(patient);
                    },
                  ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final pid = patient['patient_id'] as String;
    final patientName = '${patient['firstname']} ${patient['lastname']}';
    final unread = unreadCounts[pid] ?? 0;
    // final conversationId = conversationIds[pid]; // Passing this later when page supports it

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppTheme.tealAccent.withValues(alpha: 0.1),
          child: Icon(
            Icons.person,
            color: AppTheme.tealAccent,
          ),
        ),
        title: Text(
          patientName,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Text(
          patient['email'] ?? 'No email',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textGrey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unread > 0) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chat,
                color: AppTheme.tealAccent,
                size: 20,
              ),
            ),
          ],
        ),
        onTap: () async {
          // Navigate to individual patient chat
          final pId = patient['patient_id'] as String;
          final pName =
              '${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''}'
                  .trim();

          // Get existing or create new conversation
          String? convoId = conversationIds[pId];

          if (convoId == null) {
            // Create new conversation
            convoId = await _messagingService.getOrCreateDirectConversation(
              user1Id: widget.staffId,
              user1Role: 'staff',
              user1Name: _staffName,
              user2Id: pId,
              user2Role: 'patient',
              user2Name: pName,
              clinicId: widget.clinicId,
            );
            if (convoId == null) return;
          }

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: convoId!,
                  userId: widget.staffId,
                  userRole: 'staff',
                  userName: _staffName,
                  otherUserName: pName,
                  otherUserRole: 'patient',
                ),
              ),
            ).then((_) => _loadPatients()); // Refresh indicators on return
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.textGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No patients found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Patients with appointments will appear here',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
