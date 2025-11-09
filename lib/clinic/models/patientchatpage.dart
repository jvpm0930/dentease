import 'dart:async';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String _formatTimestamp(String timestamp) {
  final DateTime dateTime = DateTime.parse(timestamp).toLocal();
  return DateFormat('h:mm a').format(dateTime);
}

String _formatDate(String timestamp) {
  final DateTime dateTime = DateTime.parse(timestamp).toLocal();
  return DateFormat('MMM d, yyyy').format(dateTime);
}

class PatientChatPage extends StatefulWidget {
  final String patientId;
  final String clinicName;
  final String clinicId;

  const PatientChatPage({
    super.key,
    required this.patientId,
    required this.clinicName,
    required this.clinicId,
  });

  @override
  _PatientChatPageState createState() => _PatientChatPageState();
}

class _PatientChatPageState extends State<PatientChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;

  bool _autoScrollOnNewMessage = true;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select()
          .or('sender_id.eq.${widget.clinicId},receiver_id.eq.${widget.clinicId}')
          .or('sender_id.eq.${widget.patientId},receiver_id.eq.${widget.patientId}')
          .order('timestamp', ascending: true);

      final filtered = response.where((msg) =>
          (msg['sender_id'] == widget.clinicId &&
              msg['receiver_id'] == widget.patientId) ||
          (msg['sender_id'] == widget.patientId &&
              msg['receiver_id'] == widget.clinicId));

      setState(() {
        messages = List<Map<String, dynamic>>.from(filtered);
      });

      if (!_didInitialScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
          _didInitialScroll = true;
        });
      }
    } catch (_) {}
  }

  void _listenForMessages() {
    _messageSubscription =
        supabase.from('messages').stream(primaryKey: ['id']).listen((payload) {
      final relevantMessages = payload.where((msg) =>
          (msg['sender_id'] == widget.patientId &&
              msg['receiver_id'] == widget.clinicId) ||
          (msg['sender_id'] == widget.clinicId &&
              msg['receiver_id'] == widget.patientId));

      final List<Map<String, dynamic>> newMessages =
          List<Map<String, dynamic>>.from(relevantMessages)
            ..sort((a, b) =>
                (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

      setState(() {
        messages = newMessages;
      });

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

  Future<void> markClinicMessagesAsRead() async {
    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', widget.clinicId)
          .eq('receiver_id', widget.patientId)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await supabase.from('messages').insert({
        'sender_id': widget.patientId,
        'receiver_id': widget.clinicId,
        'message': text.trim(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'is_read': false,
      });
      messageController.clear();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedMessages = {};
    for (var msg in messages) {
      final ts =
          msg['timestamp']?.toString() ?? DateTime.now().toIso8601String();
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
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 8),
                itemCount: dates.length,
                itemBuilder: (context, index) {
                  final date = dates[index];
                  final dayMessages = groupedMessages[date]!;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          date,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      ...dayMessages.map((msg) {
                        final isMe = msg['sender_id'] == widget.patientId;
                        final text = msg['message'] ?? '';
                        final ts = msg['timestamp'] ??
                            DateTime.now().toIso8601String();
                        final isUnread = (msg['is_read'] == false ||
                                msg['is_read'] == null) &&
                            !isMe;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF103D7E)
                                  : (isUnread
                                      ? Colors.grey[200]
                                      : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(12),
                              border: isUnread
                                  ? Border.all(
                                      color: Colors.redAccent, width: 1)
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTimestamp(ts),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color:
                                            Color.fromARGB(255, 152, 152, 152),
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 6),
                                      const Text(
                                        "Unread",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ]
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
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: sendMessage,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF103D7E)),
                    onPressed: () => sendMessage(messageController.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
