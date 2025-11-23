import 'dart:async';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Helper: format "3:05 PM"
String _formatTimestamp(String timestamp) {
  final DateTime dateTime =
      DateTime.tryParse(timestamp)?.toLocal() ?? DateTime.now();
  return DateFormat('h:mm a').format(dateTime);
}

/// Helper: format "Nov 22, 2025"
String _formatDate(String timestamp) {
  final DateTime dateTime =
      DateTime.tryParse(timestamp)?.toLocal() ?? DateTime.now();
  return DateFormat('MMM d, yyyy').format(dateTime);
}

class ClinicChatPageforAdmin extends StatefulWidget {
  final String adminId;
  final String clinicId;

  const ClinicChatPageforAdmin({
    super.key,
    required this.adminId,
    required this.clinicId,
  });

  @override
  _ClinicChatPageforAdminState createState() => _ClinicChatPageforAdminState();
}

class _ClinicChatPageforAdminState extends State<ClinicChatPageforAdmin> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;

  bool _autoScrollOnNewMessage = true;
  bool _didInitialScroll = false;

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    

    // Track if user is near bottom to decide autoscroll
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final threshold = 80.0;
      final atBottom = _scrollController.position.pixels >=
          (_scrollController.position.maxScrollExtent - threshold);
      _autoScrollOnNewMessage = atBottom;
    });

    _listenForMessages();
    fetchMessages();
    markClinicMessagesAsRead();
    startAutoRefresh();

  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      fetchMessages();
    });
  }

  /// Fetch initial messages in this conversation
  Future<void> fetchMessages() async {
    try {
      // Server-side filter: only messages between admin and clinic
      final response = await supabase
          .from('supports')
          .select()
          .or('sender_id.eq.${widget.clinicId},receiver_id.eq.${widget.clinicId}')
          .or('sender_id.eq.${widget.adminId},receiver_id.eq.${widget.adminId}')
          .order('timestamp', ascending: true);

      setState(() {
        messages = List<Map<String, dynamic>>.from(response);
      });

      // Initial jump to bottom after first load
      if (!_didInitialScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
          _didInitialScroll = true;
        });
      }
    } catch (_) {
      // Handle or log errors as needed
    }
  }

  /// Live updates via Supabase Realtime
  void _listenForMessages() {
    _messageSubscription = supabase
        .from('supports')
        .stream(primaryKey: ['id']) // Adjust if your PK differs
        .listen((payload) {
      // Keep only messages relevant to this admin-clinic conversation
      final relevantMessages = payload.where((msg) =>
          (msg['sender_id'] == widget.adminId &&
              msg['receiver_id'] == widget.clinicId) ||
          (msg['sender_id'] == widget.clinicId &&
              msg['receiver_id'] == widget.adminId));

      final List<Map<String, dynamic>> newMessages =
          List<Map<String, dynamic>>.from(relevantMessages)
            ..sort((a, b) =>
                (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

      setState(() {
        messages = newMessages;
      });

      // Mark incoming clinic messages as read
      markClinicMessagesAsRead();

      // Autoscroll to bottom when appropriate
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

  /// For admin view, mark clinic's messages as read
  Future<void> markClinicMessagesAsRead() async {
    try {
      await supabase
          .from('supports')
          .update({'is_read': true})
          .eq('sender_id', widget.adminId)
          .eq('receiver_id', widget.clinicId)
          .eq('is_read', false);
    } catch (_) {
      // If 'is_read' column doesn't exist in 'supports', this will fail silently.
    }
  }

  /// Send message as Admin -> Clinic
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      await supabase.from('supports').insert({
        'receiver_id': widget.adminId,
        'sender_id': widget.clinicId,
        'message': text,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'is_read': false,
      });
      messageController.clear();
    } catch (e) {
      print("Error sending message");
    }
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF103D7E);
    const kBubbleMe = kPrimary;
    final kBubbleOther = Colors.grey.shade200;

    // Group messages by date for date chips
    final Map<String, List<Map<String, dynamic>>> groupedMessages = {};
    for (var msg in messages) {
      final ts =
          (msg['timestamp'] ?? DateTime.now().toIso8601String()).toString();
      final dateKey = _formatDate(ts);
      groupedMessages.putIfAbsent(dateKey, () => []).add(msg);
    }
    final dates = groupedMessages.keys.toList();

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Chat with Support",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                  border:
                                      Border.all(color: Colors.grey.shade300),
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
                            final isMe = msg['sender_id'] == widget.clinicId;
                            final text = (msg['message'] ?? '').toString();
                            final ts = (msg['timestamp'] ??
                                    DateTime.now().toIso8601String())
                                .toString();

                            // Optional 'is_read' handling if exists
                            final isUnread = (msg['is_read'] == false ||
                                    msg['is_read'] == null) &&
                                !isMe;

                            final bgColor = isMe
                                ? kBubbleMe
                                : (isUnread
                                    ? Colors.grey.shade100
                                    : kBubbleOther);
                            final textColor =
                                isMe ? Colors.white : Colors.black87;

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
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
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
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
                                                : const Color.fromARGB(
                                                    255, 152, 152, 152),
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
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            onSubmitted: (val) {
                              sendMessage(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: kPrimary,
                          child: IconButton(
                            tooltip: 'Send',
                            onPressed: () =>
                                sendMessage(messageController.text),
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
