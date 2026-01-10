import 'dart:async';
import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Conversation List Widget - Shared Inbox View
/// Shows all conversations with real-time unread badges
/// Handles different views for Dentist vs Staff
class ConversationListPage extends StatefulWidget {
  final String userId;
  final String userRole; // 'dentist' or 'staff'
  final String userName;
  final String clinicId;

  const ConversationListPage({
    super.key,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.clinicId,
  });

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage>
    with SingleTickerProviderStateMixin {
  final MessagingService _messagingService = MessagingService();

  // Theme Colors
  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kBackground = Color(0xFFF5F7FA);
  static const kTextDark = Color(0xFF1E293B);
  static const kTextGrey = Color(0xFF64748B);
  static const kWarningOrange = Color(0xFFFF9800);
  static const kSuccessGreen = Color(0xFF4CAF50);

  late TabController? _tabController;
  StreamSubscription? _conversationSubscription;

  List<Map<String, dynamic>> _allConversations = [];
  Map<String, List<Map<String, dynamic>>> _groupedConversations = {};
  bool _isLoading = true;
  bool _isDentist = false;

  @override
  void initState() {
    super.initState();
    _isDentist = widget.userRole == 'dentist';

    if (_isDentist) {
      _tabController = TabController(length: 3, vsync: this);
    }

    _loadConversations();
    _subscribeToConversations();
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _subscribeToConversations() {
    _conversationSubscription = _messagingService
        .streamUserConversations(widget.userId)
        .listen((conversations) {
      if (mounted) {
        setState(() {
          _allConversations = conversations;
          _isLoading = false;
        });
        if (_isDentist) {
          _loadGroupedConversations();
        }
      }
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);

    try {
      final conversations =
          await _messagingService.getUserConversations(widget.userId);

      if (mounted) {
        setState(() {
          _allConversations = conversations;
          _isLoading = false;
        });

        if (_isDentist) {
          await _loadGroupedConversations();
        }
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupedConversations() async {
    if (!_isDentist) return;

    final grouped = await _messagingService.getConversationsGroupedByStatus(
      widget.clinicId,
      widget.userId,
    );

    if (mounted) {
      setState(() => _groupedConversations = grouped);
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp)?.toLocal();
    if (dt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return DateFormat('h:mm a').format(dt);
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE').format(dt); // Mon, Tue, etc.
    }
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: _isDentist ? _buildDentistTabs() : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : _isDentist
              ? _buildDentistView()
              : _buildStaffView(),
    );
  }

  PreferredSizeWidget _buildDentistTabs() {
    final unansweredCount = _groupedConversations['unanswered']?.length ?? 0;
    final staffCount = _groupedConversations['handled_by_staff']?.length ?? 0;
    final myCount = _groupedConversations['my_conversations']?.length ?? 0;

    return TabBar(
      controller: _tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      labelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
      tabs: [
        _buildTab('Needs Attention', unansweredCount, isWarning: true),
        _buildTab('Staff Handling', staffCount),
        _buildTab('My Chats', myCount),
      ],
    );
  }

  Widget _buildTab(String label, int count, {bool isWarning = false}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isWarning ? kWarningOrange : kPrimaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
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

  Widget _buildDentistView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildConversationList(
          _groupedConversations['unanswered'] ?? [],
          emptyIcon: Icons.check_circle_outline,
          emptyTitle: 'All Caught Up!',
          emptySubtitle: 'No patient messages awaiting response',
        ),
        _buildConversationList(
          _groupedConversations['handled_by_staff'] ?? [],
          emptyIcon: Icons.support_agent_outlined,
          emptyTitle: 'No Staff Conversations',
          emptySubtitle: 'Staff chats will appear here',
          showHandlerBadge: true,
        ),
        _buildConversationList(
          _groupedConversations['my_conversations'] ?? [],
          emptyIcon: Icons.chat_bubble_outline,
          emptyTitle: 'No Direct Chats',
          emptySubtitle: 'Your conversations will appear here',
        ),
      ],
    );
  }

  Widget _buildStaffView() {
    return _buildConversationList(
      _allConversations,
      emptyIcon: Icons.chat_bubble_outline,
      emptyTitle: 'No Conversations',
      emptySubtitle: 'Your assigned chats will appear here',
    );
  }

  Widget _buildConversationList(
    List<Map<String, dynamic>> conversations, {
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    bool showHandlerBadge = false,
  }) {
    if (conversations.isEmpty) {
      return _buildEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: kPrimaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conv = conversations[index];
          return _buildConversationCard(conv,
              showHandlerBadge: showHandlerBadge);
        },
      ),
    );
  }

  Widget _buildConversationCard(
    Map<String, dynamic> conversation, {
    bool showHandlerBadge = false,
  }) {
    final conversationId = conversation['conversation_id'] as String;
    final type = conversation['type'] as String? ?? 'direct';
    final lastMessage = conversation['last_message_preview'] as String? ?? '';
    final lastMessageAt = conversation['last_message_at'] as String?;
    final unreadCount = conversation['unread_count'] as int? ?? 0;
    final participants = conversation['participants'] as List? ?? [];

    // Get display info
    String displayName = 'Unknown';
    String displayRole = '';
    IconData? roleIcon;
    Color roleColor = kPrimaryBlue;

    if (participants.isNotEmpty) {
      final otherParticipant = participants.first as Map<String, dynamic>;
      displayName = otherParticipant['display_name'] ?? 'Unknown';
      displayRole = otherParticipant['role'] ?? '';

      switch (displayRole) {
        case 'patient':
          roleIcon = Icons.person_outline;
          roleColor = kPrimaryBlue;
          break;
        case 'staff':
          roleIcon = Icons.badge_outlined;
          roleColor = Colors.teal;
          break;
        case 'dentist':
          roleIcon = Icons.medical_services_outlined;
          roleColor = Colors.purple;
          break;
        case 'admin':
          roleIcon = Icons.support_agent;
          roleColor = Colors.orange;
          break;
      }
    }

    // Get handler info for staff conversations
    String? handlerName;
    if (showHandlerBadge && participants.length > 1) {
      final staffParticipant = participants.firstWhere(
        (p) => p['role'] == 'staff',
        orElse: () => null,
      );
      if (staffParticipant != null) {
        handlerName = staffParticipant['display_name'];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openChat(conversation),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unreadCount > 0
                    ? kPrimaryBlue.withValues(alpha: 0.3)
                    : Colors.grey.shade100,
                width: unreadCount > 0 ? 1.5 : 1,
              ),
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
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: roleColor.withValues(alpha: 0.1),
                      child: roleIcon != null
                          ? Icon(roleIcon, color: roleColor, size: 26)
                          : Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                                fontSize: 20,
                              ),
                            ),
                    ),
                    // Unread indicator dot
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 15,
                                color: kTextDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessageAt != null)
                            Text(
                              _formatTime(lastMessageAt),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color:
                                    unreadCount > 0 ? kPrimaryBlue : kTextGrey,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Role badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              displayRole.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: roleColor,
                              ),
                            ),
                          ),
                          if (handlerName != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward,
                                size: 12, color: kTextGrey),
                            const SizedBox(width: 4),
                            Text(
                              handlerName,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.teal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Last message preview
                      Text(
                        lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                        style: GoogleFonts.poppins(
                          color: unreadCount > 0 ? kTextDark : kTextGrey,
                          fontSize: 13,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Unread Badge
                if (unreadCount > 0)
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
                  )
                else
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> conversation) async {
    final conversationId = conversation['conversation_id'] as String;
    final participants = conversation['participants'] as List? ?? [];

    String otherName = 'Chat';
    String otherRole = '';

    if (participants.isNotEmpty) {
      final other = participants.first as Map<String, dynamic>;
      otherName = other['display_name'] ?? 'Chat';
      otherRole = other['role'] ?? '';
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          userId: widget.userId,
          userRole: widget.userRole,
          userName: widget.userName,
          otherUserName: otherName,
          otherUserRole: otherRole,
        ),
      ),
    );

    // Refresh on return
    _loadConversations();
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
