import 'dart:async';
import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Patient Clinic Chat List - Shows clinics the patient can message
/// Uses the new conversation-based messaging system
class PatientClinicChatList extends StatefulWidget {
  final String patientId;

  const PatientClinicChatList({
    super.key,
    required this.patientId,
  });

  @override
  State<PatientClinicChatList> createState() => _PatientClinicChatListState();
}

class _PatientClinicChatListState extends State<PatientClinicChatList> {
  final supabase = Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();

  List<Map<String, dynamic>> clinics = [];
  Map<String, int> unreadCounts = {}; // clinicId -> unread count
  Map<String, String> conversationIds = {}; // clinicId -> conversationId
  String _patientName = 'Patient';

  bool isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadPatientName();
    _loadClinics();
    _subscribeToConversations();
  }

  Future<void> _loadPatientName() async {
    try {
      final patientData = await supabase
          .from('patients')
          .select('firstname, lastname')
          .eq('patient_id', widget.patientId)
          .maybeSingle();

      if (patientData != null && mounted) {
        setState(() {
          _patientName = '${patientData['firstname'] ?? ''} ${patientData['lastname'] ?? ''}'.trim();
          if (_patientName.isEmpty) _patientName = 'Patient';
        });
      }
    } catch (e) {
      debugPrint('Error loading patient name: $e');
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
        .eq('user_id', widget.patientId)
        .listen((data) {
          if (mounted) _loadClinics();
        });
  }

  Future<void> _loadClinics() async {
    try {
      // 1. Get clinics from patient's bookings (for new chat options)
      final bookingsResponse = await supabase
          .from('bookings')
          .select('clinic_id, clinics(clinic_id, clinic_name, email, profile_url)')
          .eq('patient_id', widget.patientId);

      // Get unique clinics
      final Map<String, Map<String, dynamic>> uniqueClinics = {};
      for (final booking in bookingsResponse) {
        final clinic = booking['clinics'];
        if (clinic != null) {
          final cid = clinic['clinic_id'] as String;
          uniqueClinics[cid] = clinic;
        }
      }

      // 2. Get unread counts from conversation_participants
      final myParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id, unread_count')
          .eq('user_id', widget.patientId)
          .eq('is_active', true);

      final activeConvoIds = myParticipants
          .map((p) => p['conversation_id'] as String)
          .toList();

      Map<String, int> uCounts = {};
      Map<String, String> cIds = {};

      if (activeConvoIds.isNotEmpty) {
        // Get all participants to find which conversations involve which clinics
        final allParticipants = await supabase
            .from('conversation_participants')
            .select('conversation_id, user_id, role, display_name')
            .inFilter('conversation_id', activeConvoIds);

        // Also get conversation details to find clinic_id
        final convos = await supabase
            .from('conversations')
            .select('conversation_id, clinic_id')
            .inFilter('conversation_id', activeConvoIds);

        // Map conversation_id to clinic_id
        final convoToClinic = <String, String>{};
        for (var c in convos) {
          final cid = c['clinic_id'];
          if (cid != null) {
            convoToClinic[c['conversation_id'] as String] = cid as String;
          }
        }

        for (var myP in myParticipants) {
          final convoId = myP['conversation_id'] as String;
          final count = (myP['unread_count'] as int?) ?? 0;

          // Get the clinic_id for this conversation
          final clinicId = convoToClinic[convoId];
          if (clinicId != null && uniqueClinics.containsKey(clinicId)) {
            uCounts[clinicId] = (uCounts[clinicId] ?? 0) + count;
            cIds[clinicId] = convoId;
          }
        }
      }

      if (mounted) {
        setState(() {
          clinics = uniqueClinics.values.toList();
          unreadCounts = uCounts;
          conversationIds = cIds;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading clinics: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _openChat(Map<String, dynamic> clinic) async {
    final clinicId = clinic['clinic_id'] as String;
    final clinicName = clinic['clinic_name'] ?? 'Clinic';

    // Get or create conversation
    String? convoId = conversationIds[clinicId];

    if (convoId == null) {
      convoId = await _messagingService.getOrCreateDirectConversation(
        user1Id: widget.patientId,
        user1Role: 'patient',
        user1Name: _patientName,
        user2Id: clinicId,
        user2Role: 'dentist',
        user2Name: clinicName,
        clinicId: clinicId,
      );
    }

    if (convoId != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convoId!,
            userId: widget.patientId,
            userRole: 'patient',
            userName: _patientName,
            otherUserName: clinicName,
            otherUserRole: 'dentist',
          ),
        ),
      );
      _loadClinics(); // Refresh on return
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'My Messages',
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: AppTheme.textDark),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : clinics.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadClinics,
                  color: AppTheme.primaryBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: clinics.length,
                    itemBuilder: (context, index) {
                      return _buildClinicCard(clinics[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildClinicCard(Map<String, dynamic> clinic) {
    final clinicId = clinic['clinic_id'] as String;
    final clinicName = clinic['clinic_name'] ?? 'Unknown Clinic';
    final email = clinic['email'] ?? '';
    final profileUrl = clinic['profile_url'] as String?;
    final unread = unreadCounts[clinicId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
              child: profileUrl == null
                  ? Icon(Icons.local_hospital_rounded, color: AppTheme.primaryBlue, size: 28)
                  : null,
            ),
            if (unread > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : unread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          clinicName,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Text(
          email,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textGrey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unread > 0)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chat,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
          ],
        ),
        onTap: () => _openChat(clinic),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book an appointment to start chatting with clinics',
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
