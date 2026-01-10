import 'dart:async';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Chat Screen - Real-time Messaging UI
/// Uses Supabase streams for live message updates
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String userId;
  final String userRole;
  final String userName;
  final String otherUserName;
  final String otherUserRole;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.otherUserName,
    required this.otherUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _messageSubscription;
  bool _isLoading = true;
  bool _autoScroll = true;

  // Optimistic message tracking
  final Set<String> _pendingMessageIds = {};

  // Cache for resolved sender names (sender_id -> actual name)
  final Map<String, String> _senderNameCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _subscribeToMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    _autoScroll = (maxScroll - currentScroll) <= 100;
  }

  Future<void> _loadMessages() async {
    try {
      final messages =
          await _messagingService.getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom(animated: false);
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _messageSubscription = _messagingService
        .streamMessages(widget.conversationId)
        .listen((messages) {
      if (mounted) {
        // Filter out any pending optimistic messages that now have real versions
        final realMessageIds = messages.map((m) => m['message_id']).toSet();
        _pendingMessageIds.removeWhere((id) => realMessageIds.contains(id));

        setState(() {
          _messages = messages;
        });

        if (_autoScroll) _scrollToBottom();
        _markAsRead();
      }
    });
  }

  Future<void> _markAsRead() async {
    await _messagingService.markConversationAsRead(
      widget.conversationId,
      widget.userId,
    );
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    // Create optimistic message
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'message_id': tempId,
      'conversation_id': widget.conversationId,
      'sender_id': widget.userId,
      'sender_role': widget.userRole,
      'sender_name': widget.userName,
      'content': text,
      'message_type': 'text',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_pending': true,
    };

    setState(() {
      _messages.add(tempMsg);
      _pendingMessageIds.add(tempId);
    });
    _scrollToBottom();

    // Send to server
    final result = await _messagingService.sendMessage(
      conversationId: widget.conversationId,
      senderId: widget.userId,
      senderRole: widget.userRole,
      senderName: widget.userName,
      content: text,
    );

    if (result == null && mounted) {
      // Failed - remove optimistic message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _messages.removeWhere((m) => m['message_id'] == tempId);
        _pendingMessageIds.remove(tempId);
      });
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp)?.toLocal();
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt);
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp)?.toLocal();
    if (dt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) return 'Today';
    if (msgDate == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'patient':
        return AppTheme.primaryBlue;
      case 'staff':
        return AppTheme.successColor;
      case 'dentist':
        return const Color(0xFF9C27B0); // Purple for dentist
      case 'admin':
        return AppTheme.warningColor;
      default:
        return AppTheme.textGrey;
    }
  }

  /// Resolve sender name - returns cached name or looks up actual name for generic names
  Future<String> _resolveSenderName(
      String senderId, String senderRole, String currentName) async {
    // Check if we have a cached name
    if (_senderNameCache.containsKey(senderId)) {
      return _senderNameCache[senderId]!;
    }

    // If the current name is generic, look up the actual name
    final lowerName = currentName.toLowerCase();
    final isGeneric = currentName.isEmpty ||
        lowerName == 'clinic' ||
        lowerName == 'dentist' ||
        lowerName == 'staff' ||
        currentName == 'Dr. ';

    if (!isGeneric) {
      _senderNameCache[senderId] = currentName;
      return currentName;
    }

    try {
      String? resolvedName;

      if (senderRole == 'dentist') {
        // Try by 'id' column first (auth user id)
        var dentistData = await _supabase
            .from('dentists')
            .select('firstname, lastname')
            .eq('id', senderId)
            .maybeSingle();

        // If not found, try by dentist_id
        if (dentistData == null) {
          dentistData = await _supabase
              .from('dentists')
              .select('firstname, lastname')
              .eq('dentist_id', senderId)
              .maybeSingle();
        }

        if (dentistData != null) {
          final firstName = dentistData['firstname']?.toString().trim() ?? '';
          final lastName = dentistData['lastname']?.toString().trim() ?? '';
          final name = '$firstName $lastName'.trim();
          if (name.isNotEmpty && name != ' ') {
            resolvedName = 'Dr. $name';
          }
        }
      } else if (senderRole == 'staff') {
        // Try by 'id' column first (auth user id)
        var staffData = await _supabase
            .from('staffs')
            .select('firstname, lastname')
            .eq('id', senderId)
            .maybeSingle();

        // If not found, try by staff_id
        if (staffData == null) {
          staffData = await _supabase
              .from('staffs')
              .select('firstname, lastname')
              .eq('staff_id', senderId)
              .maybeSingle();
        }

        if (staffData != null) {
          final firstName = staffData['firstname']?.toString().trim() ?? '';
          final lastName = staffData['lastname']?.toString().trim() ?? '';
          final name = '$firstName $lastName'.trim();
          if (name.isNotEmpty && name != ' ') {
            resolvedName = name;
          }
        }
      } else if (senderRole == 'patient') {
        // Try by 'id' column first (auth user id)
        var patientData = await _supabase
            .from('patients')
            .select('firstname, lastname')
            .eq('id', senderId)
            .maybeSingle();

        // If not found, try by patient_id
        if (patientData == null) {
          patientData = await _supabase
              .from('patients')
              .select('firstname, lastname')
              .eq('patient_id', senderId)
              .maybeSingle();
        }

        if (patientData != null) {
          final firstName = patientData['firstname']?.toString().trim() ?? '';
          final lastName = patientData['lastname']?.toString().trim() ?? '';
          final name = '$firstName $lastName'.trim();
          if (name.isNotEmpty && name != ' ') {
            resolvedName = name;
          }
        }
      }

      final finalName = resolvedName ?? currentName;
      _senderNameCache[senderId] = finalName;
      return finalName;
    } catch (e) {
      debugPrint('Error resolving sender name: $e');
      _senderNameCache[senderId] = currentName;
      return currentName;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group messages by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var m in _messages) {
      final dateKey = _formatDate(m['created_at']?.toString());
      grouped.putIfAbsent(dateKey, () => []).add(m);
    }
    final dates = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryBlue),
                  )
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: dates.length,
                        itemBuilder: (context, index) {
                          final date = dates[index];
                          final dayMessages = grouped[date]!;
                          return Column(
                            children: [
                              _buildDateChip(date),
                              ...dayMessages
                                  .map((msg) => _buildMessageBubble(msg)),
                            ],
                          );
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: const BackButton(color: Colors.white),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              widget.otherUserName.isNotEmpty
                  ? widget.otherUserName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.otherUserRole.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {
            // TODO: Show chat options menu
          },
        ),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: AppTheme.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.otherUserName}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textGrey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          date,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == widget.userId;
    final isPending = msg['is_pending'] == true;
    final senderName = msg['sender_name'] ?? '';
    final senderRole = msg['sender_role'] ?? '';
    final senderId = msg['sender_id'] ?? '';
    final text = msg['content'] ?? '';
    final timestamp = msg['created_at']?.toString() ?? '';

    // Determine bubble color
    Color bubbleColor;
    Color textColor;
    if (isMe) {
      bubbleColor = AppTheme.primaryBlue;
      textColor = Colors.white;
    } else {
      bubbleColor = Colors.white;
      textColor = AppTheme.textDark;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Show sender name for others (with name resolution)
            if (!isMe && senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: FutureBuilder<String>(
                  future: _resolveSenderName(senderId, senderRole, senderName),
                  builder: (context, snapshot) {
                    final displayName = snapshot.data ?? senderName;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(senderRole),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: _getRoleColor(senderRole)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            senderRole.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _getRoleColor(senderRole),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            // Message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(timestamp),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : AppTheme.textGrey,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: isMe ? Colors.white70 : AppTheme.textGrey,
                          ),
                        ),
                      ] else if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment button (optional)
            IconButton(
              icon: Icon(Icons.attach_file, color: AppTheme.textGrey),
              onPressed: () {
                // TODO: Implement attachment picker
              },
            ),
            // Message input
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.poppins(color: AppTheme.textGrey),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            // Send button
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
