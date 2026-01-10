import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Admin Chat List - Shows all approved clinics for chat
class AdminChatListPage extends StatefulWidget {
  const AdminChatListPage({super.key});

  @override
  State<AdminChatListPage> createState() => _AdminChatListPageState();
}

class _AdminChatListPageState extends State<AdminChatListPage> {
  final supabase = Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();

  static const kPrimaryBlue = Color(0xFF1134A6);
  static const kBackground = Color(0xFFF8FAFC);

  Map<String, int> _unreadCounts = {}; // clinicId -> count
  Map<String, String> _convoIds = {}; // clinicId -> convoId
  StreamSubscription? _unreadSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToUnreadCounts();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToUnreadCounts() {
    final adminId = supabase.auth.currentUser?.id;
    if (adminId == null) return;

    // Listen to changes in conversation_participants for the Admin
    _unreadSubscription = supabase
        .from('conversation_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', adminId)
        .listen((myParticipants) async {
          if (!mounted) return;

          final Map<String, int> newCounts = {};
          final Map<String, String> newConvoIds = {};

          if (myParticipants.isNotEmpty) {
            final convoIds = myParticipants
                .map((p) => p['conversation_id'] as String)
                .toList();

            // Fetch conversation metadata to map to clinic_id
            final convos = await supabase
                .from('conversations')
                .select('conversation_id, clinic_id')
                .inFilter('conversation_id', convoIds);

            for (var p in myParticipants) {
              final cid = p['conversation_id'] as String;
              final unread = (p['unread_count'] as int?) ?? 0;
              final convo = convos.firstWhere(
                  (c) => c['conversation_id'] == cid,
                  orElse: () => {});
              final clinicId = convo['clinic_id'] as String?;

              if (clinicId != null) {
                newCounts[clinicId] = unread;
                newConvoIds[clinicId] = cid;
              }
            }
          }

          if (mounted) {
            setState(() {
              _unreadCounts = newCounts;
              _convoIds = newConvoIds;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final adminId = supabase.auth.currentUser?.id;

    if (adminId == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in")),
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Clinic Chat',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Show all approved clinics as before
        stream: supabase.from('clinics').stream(primaryKey: ['clinic_id']).map(
            (clinics) =>
                clinics.where((c) => c['status'] == 'approved').toList()
                  ..sort((a, b) {
                    final idA = a['clinic_id'];
                    final idB = b['clinic_id'];
                    final unreadA = _unreadCounts[idA] ?? 0;
                    final unreadB = _unreadCounts[idB] ?? 0;
                    if (unreadA != unreadB) return unreadB.compareTo(unreadA);
                    return (a['clinic_name'] as String? ?? '')
                        .compareTo(b['clinic_name'] as String? ?? '');
                  })),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _unreadCounts.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue));
          }

          final clinics = snapshot.data ?? [];

          if (clinics.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No clinics found',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: clinics.length,
            itemBuilder: (context, index) {
              final clinic = clinics[index];
              final clinicId = clinic['clinic_id'];
              final clinicName = clinic['clinic_name'] ?? 'Unknown Clinic';
              final email = clinic['email'] ?? '';
              final profileUrl = clinic['profile_url'] as String?;
              final unread = _unreadCounts[clinicId] ?? 0;
              final conversationId = _convoIds[clinicId];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: kPrimaryBlue.withValues(alpha: 0.1),
                        backgroundImage: profileUrl != null
                            ? NetworkImage(profileUrl)
                            : null,
                        child: profileUrl == null
                            ? const Icon(Icons.local_hospital_rounded,
                                color: kPrimaryBlue, size: 28)
                            : null,
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: Text(
                              unread > 9 ? '9+' : unread.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    clinicName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    email,
                    style: GoogleFonts.roboto(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                  trailing: unread > 0
                      ? const Icon(Icons.circle, size: 12, color: Colors.red)
                      : const Icon(Icons.chat_bubble_outline,
                          color: kPrimaryBlue),
                  onTap: () async {
                    String? convoId = conversationId;

                    if (convoId == null) {
                      // Show loading or just do it
                      convoId =
                          await _messagingService.getOrCreateDirectConversation(
                        user1Id: adminId,
                        user1Role: 'admin',
                        user1Name: 'Admin Support',
                        user2Id: clinicId,
                        user2Role: 'dentist',
                        user2Name: clinicName,
                        clinicId: clinicId,
                      );
                    }

                    if (convoId != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: convoId!,
                            userId: adminId,
                            userRole: 'admin',
                            userName: 'Admin Support',
                            otherUserName: clinicName,
                            otherUserRole: 'dentist',
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
