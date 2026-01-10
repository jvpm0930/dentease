import 'package:dentease/admin/pages/clinics/admin_dentease_pending.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminNotificationPage extends StatefulWidget {
  const AdminNotificationPage({super.key});

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<NotificationItem> notifications = [];

  static const kPrimaryBlue = Color(0xFF1134A6);
  static const kBackground = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final adminId = supabase.auth.currentUser?.id;
    if (adminId == null) return;

    try {
      // 1. Fetch Pending Clinics
      final pendingClinics = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, created_at')
          .eq('status', 'pending');

      // 2. Fetch Unread Messages
      final unreadMessages = await supabase
          .from('supports')
          .select('id, sender_id, message, timestamp, clinics(clinic_name)')
          .eq('receiver_id', adminId)
          .eq('is_read', false);

      List<NotificationItem> items = [];

      // Process Clinics
      for (var clinic in pendingClinics) {
        items.add(NotificationItem(
          id: clinic['clinic_id'],
          title: 'New Clinic Application',
          body: '${clinic['clinic_name']} has applied for verification.',
          timestamp: DateTime.parse(clinic['created_at']),
          type: NotificationType.application,
          referenceId: clinic['clinic_id'],
        ));
      }

      // Process Messages
      for (var msg in unreadMessages) {
        final clinicData = msg['clinics'] as Map<String, dynamic>?;
        final clinicName = clinicData?['clinic_name'] ?? 'Unknown Clinic';

        items.add(NotificationItem(
          id: msg['id'].toString(),
          title: 'New Message',
          body: 'From $clinicName: ${msg['message']}',
          timestamp: DateTime.parse(msg['timestamp']),
          type: NotificationType.message,
          referenceId: msg['sender_id'],
          referenceName: clinicName,
        ));
      }

      // Sort by newest first
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          notifications = items;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _handleTap(NotificationItem item) async {
    if (item.type == NotificationType.application) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const AdminPendingPage(showBackButton: true)),
      );
    } else if (item.type == NotificationType.message) {
      final adminId = supabase.auth.currentUser?.id;
      if (adminId != null) {
        // Mark message as read before navigating
        await _markMessageAsRead(item.id);

        // TODO: Implement AdminSupportChatPage
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat feature coming soon')),
        );

        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => AdminSupportChatPage(
        //       clinicId: item.referenceId,
        //       clinicName: item.referenceName ?? 'Clinic',
        //       adminId: adminId,
        //     ),
        //   ),
        // ).then((_) {
        //   // Refresh notifications when returning from chat
        //   _fetchNotifications();
        // });
      }
    }
  }

  Future<void> _markMessageAsRead(String messageId) async {
    try {
      await supabase
          .from('supports')
          .update({'is_read': true}).eq('id', int.parse(messageId));
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Text(
            'Notifications',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue))
            : notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No new notifications',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      separatorBuilder: (ctx, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return _buildNotificationCard(item);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    Color iconColor;
    IconData iconData;
    Color? backgroundColor;

    switch (item.type) {
      case NotificationType.application:
        iconColor = Colors.orange;
        iconData = Icons.assignment_ind_rounded;
        backgroundColor = Colors.orange.withValues(alpha: 0.05);
        break;
      case NotificationType.message:
        iconColor = kPrimaryBlue;
        iconData = Icons.chat_bubble_rounded;
        backgroundColor = kPrimaryBlue.withValues(alpha: 0.05);
        break;
      default:
        iconColor = Colors.grey;
        iconData = Icons.notifications;
    }

    final timeAgo = _getTimeAgo(item.timestamp);

    return InkWell(
      onTap: () => _handleTap(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.type == NotificationType.message
                ? kPrimaryBlue.withValues(alpha: 0.2)
                : Colors.grey.shade200,
            width: item.type == NotificationType.message ? 1.5 : 1,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: const Color(0xFF0D1B2A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          timeAgo,
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Show clinic name prominently for messages
                  if (item.type == NotificationType.message &&
                      item.referenceName != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kPrimaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_hospital_rounded,
                            size: 14,
                            color: kPrimaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.referenceName!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    item.body,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.type == NotificationType.message)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            size: 14,
                            color: kPrimaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to reply',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: kPrimaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

enum NotificationType { application, message, other }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final String referenceId;
  final String? referenceName;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    required this.referenceId,
    this.referenceName,
  });
}
