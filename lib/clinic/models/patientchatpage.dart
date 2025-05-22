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

class PatientChatpage extends StatefulWidget {
  final String patientId;
  final String clinicName;
  final String clinicId;

  const PatientChatpage({
    super.key,
    required this.patientId,
    required this.clinicName,
    required this.clinicId,
  });

  @override
  _PatientChatpageState createState() => _PatientChatpageState();
}

class _PatientChatpageState extends State<PatientChatpage> {
  final supabase = Supabase.instance.client;
  final TextEditingController messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchMessages();
    startAutoRefresh();
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      fetchMessages();
    });
  }

  Future<void> fetchMessages() async {
    final response = await supabase
        .from('messages')
        .select()
        .or('sender_id.eq.${widget.patientId},receiver_id.eq.${widget.patientId}')
        .or('sender_id.eq.${widget.clinicId},receiver_id.eq.${widget.clinicId}')
        .order('timestamp', ascending: true);

    setState(() {
      messages = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty) return;

    try {
      await supabase.from('messages').insert({
        'receiver_id': widget.clinicId,
        'sender_id': widget.patientId,
        'message': text,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      messageController.clear();
      fetchMessages();
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedMessages = {};

    for (var message in messages) {
      String dateKey = _formatDate(message['timestamp']);
      if (!groupedMessages.containsKey(dateKey)) {
        groupedMessages[dateKey] = [];
      }
      groupedMessages[dateKey]!.add(message);
    }

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Chat with ${widget.clinicName}",
            style: TextStyle(color: Colors.white),
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
                itemCount: groupedMessages.length,
                itemBuilder: (context, groupIndex) {
                  String date = groupedMessages.keys.elementAt(groupIndex);
                  List<Map<String, dynamic>> dayMessages =
                      groupedMessages[date]!;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      ...dayMessages.map((message) {
                        final isMe = message['sender_id'] == widget.patientId;
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[200] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['message'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  _formatTimestamp(message['timestamp']),
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[700]),
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
              padding: EdgeInsets.all(10),
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
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.blue),
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
