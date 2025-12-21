import 'package:dentease/admin/pages/clinics/admin_dentease_first.dart';
import 'package:dentease/clinic/models/adminChat_supportList.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';


/// -----------------------------------------
///  LOCAL NOTIFICATION CONFIG
/// -----------------------------------------
final FlutterLocalNotificationsPlugin adminNotificationPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initAdminNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await adminNotificationPlugin.initialize(initSettings);
}

Future<void> showAdminNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'admin_chat_channel',
    'Admin Message Alerts',
    channelDescription: 'Notifications for admin chat updates from clinics',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  final id = Random().nextInt(9999999);

  await adminNotificationPlugin.show(
    id,
    title,
    body,
    NotificationDetails(android: androidDetails),
  );
}

/// -----------------------------------------
///  ADMIN FOOTER WITH CHAT NOTIFICATION
/// -----------------------------------------
class AdminFooter extends StatefulWidget {
  const AdminFooter({super.key});

  @override
  _AdminFooterState createState() => _AdminFooterState();
}

class _AdminFooterState extends State<AdminFooter> {
  final supabase = Supabase.instance.client;
  String clinicNotifyKey = "admin_clinic_notify_flag";
  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;

  // Badge indicator
  bool hasNewClinicChats = false;

  // Prevent duplicate notification alert
  Set<String> notifiedAdminMessageIds = {};

  // Background poll timer
  Timer? _adminRefreshTimer;

  @override
  void initState() {
    super.initState();
    initAdminNotifications();
    loadAdminNotifiedChatIds();
    fetchAdminChats();
    _loadNotifyFlag();
    _fetchClinics();

    // Check chats every seconds
    _adminRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => fetchAdminChats(),
    );

    supabase
        .channel('clinic-notify')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'clinics',
          callback: (payload) async {
            final newNotify = payload.newRecord['notify'];
            final oldNotify = payload.oldRecord['notify'];

            if (newNotify == oldNotify || newNotify == null || newNotify == "") {
              return;
            }

            String clinicName = payload.newRecord['clinic_name'] ?? "Clinic";

            await showAdminNotification(
                "Clinic Alert", "$clinicName Resubmit Detail Application");

            //  SAVE BADGE STATE IN STORAGE
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(clinicNotifyKey, true);

            if (mounted) setState(() => hasNewClinicChats = true);
          },
        )
        .subscribe();
  }
  Future<void> _loadNotifyFlag() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hasNewClinicChats = prefs.getBool(clinicNotifyKey) ?? false;
    });
  }

  @override
  void dispose() {
    _adminRefreshTimer?.cancel(); // stop timer
    supabase.removeAllChannels(); // remove realtime listeners
    super.dispose();
  }

  Future<void> loadAdminNotifiedChatIds() async {
    final prefs = await SharedPreferences.getInstance();
    notifiedAdminMessageIds =
        (prefs.getStringList('admin_notified_chat_ids') ?? []).toSet();
  }

  Future<void> saveAdminNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'admin_notified_chat_ids', notifiedAdminMessageIds.toList());
  }

  Future<void> _fetchClinics() async {
    try {
      final response =
          await supabase.from('clinics').select('clinic_id, clinic_name');

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Error fetching clinics: $e');
      setState(() => isLoading = false);
    }
  }

  /// -----------------------------------------------------------
  /// CHECK NEW MESSAGES SENT TO ADMIN SUPPORT PANEL
  /// -----------------------------------------------------------
  Future<void> fetchAdminChats() async {
    try {
      final response = await supabase
          .from('supports')
          .select('support_id, message, sender_id')
          .eq('receiver_id', 'eee5f574-903b-4575-a9d9-2f69e58f1801') // ADMIN UID
          .or('is_read.eq.false,is_read.is.null')
          .order('timestamp', ascending: true);

      if (response.isNotEmpty) setState(() => hasNewClinicChats = true);

      for (var chat in response) {
        final id = chat['support_id'].toString();

        // Already notified? skip
        if (notifiedAdminMessageIds.contains(id)) continue;

        notifiedAdminMessageIds.add(id);
        saveAdminNotifiedIds();

        // Fetch clinic name for notification title
        final clinicData = await supabase
            .from('clinics')
            .select('clinic_name')
            .eq('clinic_id', chat['sender_id'])
            .maybeSingle();

        final clinicName = clinicData?['clinic_name'] ?? "Clinic";

        //  Send Notification
        await showAdminNotification(
          "New Message from $clinicName",
          chat['message'] ?? "Sent a new support inquiry.",
        );
      }
    } catch (e) {
      debugPrint("ADMIN NOTIFICATION ERROR → $e");
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  

  @override
  Widget build(BuildContext context) {
    final clinicId = clinics.isNotEmpty ? clinics.first['clinic_id'] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF103D7E),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),

      // bottom nav
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _nav('assets/icons/home.png', const AdminPage()),

          // CHAT SUPPORT ICON WITH BADGE
          IconButton(
            iconSize: 35,
            icon: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset('assets/icons/customer-service.png',
                    width: 30, height: 30, color: Colors.white),
                if (hasNewClinicChats)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminSupportChatforClinic(
                    adminId: 'eee5f574-903b-4575-a9d9-2f69e58f1801',
                  ),
                ),
              );
              setState(
                  () => hasNewClinicChats = false); // remove badge when opened
            },
          ),
        ],
      ),
    );
  }

  Widget _nav(String icon, Widget page) {
    return IconButton(
      icon: Image.asset(icon, width: 30, height: 30, color: Colors.white),
      onPressed: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}
