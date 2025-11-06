import 'dart:async';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> showLocalNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'chat_channel',
    'Chat Notifications',
    channelDescription: 'Notification channel for new chat messages',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformDetails,
  );
}

String _formatTimestamp(String timestamp) {
  final DateTime dateTime = DateTime.parse(timestamp).toLocal();
  return DateFormat('h:mm a').format(dateTime);
}

String _formatDate(String timestamp) {
  final DateTime dateTime = DateTime.parse(timestamp).toLocal();
  return DateFormat('MMM d, yyyy').format(dateTime);
}

class ClinicChatPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String clinicId;

  const ClinicChatPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.clinicId,
  });

  @override
  _ClinicChatPageState createState() => _ClinicChatPageState();
}

class _ClinicChatPageState extends State<ClinicChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController messageController = TextEditingController();

  List<Map<String, dynamic>> messages = [];
  Timer? refreshTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _listenForMessages();
    fetchMessages();
    startAutoRefresh();
    markPatientMessagesAsRead(); // Mark unread messages as read upon opening
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    messageController.dispose();
    stopAutoRefresh();
    super.dispose();
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      fetchMessages();
    });
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
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  /// Real-time listener for messages in this chat
  int lastUnreadCount = 0;

  void _listenForMessages() {
    _messageSubscription = supabase
        .from('messages')
        .stream(primaryKey: ['id']).listen((payload) async {
      final relevantMessages = payload.where((m) =>
          (m['sender_id'] == widget.patientId &&
              m['receiver_id'] == widget.clinicId) ||
          (m['sender_id'] == widget.clinicId &&
              m['receiver_id'] == widget.patientId));

      final List<Map<String, dynamic>> newMessages =
          List<Map<String, dynamic>>.from(relevantMessages);

      // Update messages in state
      setState(() {
        messages = newMessages;
      });

      // Count unread messages from patient
      final unreadMessages = newMessages.where((msg) =>
          msg['sender_id'] == widget.patientId &&
          msg['receiver_id'] == widget.clinicId &&
          (msg['is_read'] == false || msg['is_read'] == null));

      final currentUnreadCount = unreadMessages.length;

      // Only trigger notification if new unread messages appear
      if (currentUnreadCount > lastUnreadCount && unreadMessages.isNotEmpty) {
        final latestUnread = unreadMessages.last;
        await showLocalNotification(
          'New message from ${widget.patientName}',
          latestUnread['message'],
        );
      }

      // Update the tracker
      lastUnreadCount = currentUnreadCount;
    });
  }


  /// Mark all patient messages as read when opening or replying
  Future<void> markPatientMessagesAsRead() async {
    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', widget.patientId)
          .eq('receiver_id', widget.clinicId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking patient messages as read: $e');
    }
  }

  /// Send message (clinic → patient)
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await supabase.from('messages').insert({
        'sender_id': widget.clinicId,
        'receiver_id': widget.patientId,
        'message': text.trim(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'is_read': false,
      });

      messageController.clear();
      setState(() {
        lastUnreadCount = 0; // reset local unread tracker
      });

      // Mark all patient messages as read after sending a reply
      await markPatientMessagesAsRead();
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  void stopAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
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

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Chat with ${widget.patientName}",
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
                padding: const EdgeInsets.only(top: 8),
                itemCount: groupedMessages.length,
                itemBuilder: (context, index) {
                  final date = groupedMessages.keys.elementAt(index);
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
                        final isMe = msg['sender_id'] == widget.clinicId;
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
                                  ? Colors.blue[300]
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
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 6),
                                      Text(
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
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
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
