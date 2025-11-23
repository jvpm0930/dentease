
import 'dart:async';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Helper: format "3:05 PM"
String _formatTimestamp(String timestamp) {
  final DateTime dateTime = DateTime.tryParse(timestamp)?.toLocal() ?? DateTime.now();
  return DateFormat('h:mm a').format(dateTime);
}

/// Helper: format "Nov 22, 2025"
String _formatDate(String timestamp) {
  final DateTime dateTime = DateTime.tryParse(timestamp)?.toLocal() ?? DateTime.now();
  return DateFormat('MMM d, yyyy').format(dateTime);
}

class AdminSupportChatPage extends StatefulWidget {
  final String clinicId;
  final String clinicName;
  final String adminId;

  const AdminSupportChatPage({
    super.key,
    required this.clinicId,
    required this.clinicName,
    required this.adminId,
  });

  @override
  _AdminSupportChatPageState createState() => _AdminSupportChatPageState();
}

class _AdminSupportChatPageState extends State<AdminSupportChatPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;

  bool _autoScrollOnNewMessage = true;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();

    // Track if user is near bottom to decide autoscroll
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      const threshold = 80.0;
      final atBottom = _scrollController.position.pixels >=
          (_scrollController.position.maxScrollExtent - threshold);
      _autoScrollOnNewMessage = atBottom;
    });

    _listenForMessages();
    fetchMessages();
    markClinicMessagesAsRead();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Initial fetch of this conversation's messages
  Future<void> fetchMessages() async {
    try {
      final response = await supabase
          .from('supports')
          .select()
          .or('sender_id.eq.${widget.adminId},receiver_id.eq.${widget.adminId}')
          .or('sender_id.eq.${widget.clinicId},receiver_id.eq.${widget.clinicId}')
          .order('timestamp', ascending: true);

      setState(() {
        messages = List<Map<String, dynamic>>.from(response);
      });

      // Jump to bottom after first load
      if (!_didInitialScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
          _didInitialScroll = true;
        });
      }
    } catch (_) {
      // Optionally log error
    }
  }

  /// Realtime updates for supports table
  void _listenForMessages() {
    _messageSubscription = supabase
        .from('supports')
        .stream(primaryKey: ['id']) // Update if your PK differs
        .listen((payload) {
      // Filter messages for this specific conversation (admin <-> clinic)
      final relevant = payload.where((msg) {
        final s = msg['sender_id'];
        final r = msg['receiver_id'];
        return (s == widget.adminId && r == widget.clinicId) ||
            (s == widget.clinicId && r == widget.adminId);
      });

      final List<Map<String, dynamic>> newMessages =
          List<Map<String, dynamic>>.from(relevant)
            ..sort((a, b) {
              final aTs = a['timestamp']?.toString() ?? '';
              final bTs = b['timestamp']?.toString() ?? '';
              return aTs.compareTo(bTs);
            });

      setState(() {
        messages = newMessages;
      });

      // Mark incoming clinic messages as read (if column exists)
      markClinicMessagesAsRead();

      // Autoscroll if user is near the bottom
      if (_autoScrollOnNewMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  /// Admin reading messages from clinic -> mark as read
  Future<void> markClinicMessagesAsRead() async {
    try {
      await supabase
          .from('supports')
          .update({'is_read': true})
          .eq('sender_id', widget.clinicId)
          .eq('receiver_id', widget.adminId)
          .eq('is_read', false);
    } catch (_) {
      // If is_read doesn't exist, ignore
    }
  }

  /// Send message as Admin -> Clinic
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      await supabase.from('supports').insert({
        'sender_id': widget.adminId,
        'receiver_id': widget.clinicId,
        'message': trimmed,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'is_read': false, // only if the column exists
      });

      messageController.clear();

      // Optionally keep focus or dismiss keyboard
      // FocusScope.of(context).unfocus();
    } catch (_) {
      // Optionally log or show a snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF103D7E);
    const kBubbleMe = kPrimary;
    final kBubbleOther = Colors.grey.shade200;

    // Group messages by date for date chips
    final Map<String, List<Map<String, dynamic>>> groupedMessages = {};
    for (final msg in messages) {
      final ts = (msg['timestamp'] ?? DateTime.now().toIso8601String()).toString();
      final dateKey = _formatDate(ts);
      groupedMessages.putIfAbsent(dateKey, () => []).add(msg);
    }
    final dates = groupedMessages.keys.toList();

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Chat with ${widget.clinicName}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Messages list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      final date = dates[index];
                      final dayMessages = groupedMessages[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Date chip
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Messages for the day
                          ...dayMessages.map((msg) {
                            final isMe = msg['sender_id'] == widget.adminId;
                            final text = (msg['message'] ?? '').toString();
                            final ts = (msg['timestamp'] ??
                                    DateTime.now().toIso8601String())
                                .toString();

                            // Optional 'is_read' handling if exists
                            final isUnread =
                                (msg['is_read'] == false || msg['is_read'] == null) &&
                                !isMe;

                            final bgColor = isMe
                                ? kBubbleMe
                                : (isUnread ? Colors.grey.shade100 : kBubbleOther);
                            final textColor = isMe ? Colors.white : Colors.black87;

                            return Align(
                              alignment:
                                  isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(isMe ? 14 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 14),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTimestamp(ts),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white70
                                                : const Color.fromARGB(255, 152, 152, 152),
                                          ),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            "Unread",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),

                // Input Bar
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: "Type a message...",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            onSubmitted: (val) => sendMessage(val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: kPrimary,
                          child: IconButton(
                            tooltip: 'Send',
                            onPressed: () => sendMessage(messageController.text),
                            icon: const Icon(Icons.send, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}