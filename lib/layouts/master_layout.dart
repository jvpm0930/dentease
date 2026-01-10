import 'package:dentease/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Master Layout for all role dashboards
/// Provides consistent AppBar with logout, and Bottom Navigation
class MasterLayout extends StatefulWidget {
  final Widget body;
  final int currentIndex;
  final List<BottomNavigationBarItem> navItems;
  final ValueChanged<int> onNavTap;
  final String? title;
  final List<Widget>? actions;
  final String? userId; // For notification service
  final String? userRole; // For notification service
  final bool showAppBar; // To optionally hide the app bar

  // Clean Medical Theme Colors
  static const Color primaryBlue =
      Color(0xFF1134A6); // Primary Blue - Headers, main actions
  static const Color inactiveGrey = Color(0xFF757575);

  const MasterLayout({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.navItems,
    required this.onNavTap,
    this.title,
    this.actions,
    this.userId,
    this.userRole,
    this.showAppBar = true,
  });

  @override
  State<MasterLayout> createState() => _MasterLayoutState();
}

class _MasterLayoutState extends State<MasterLayout> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  NotificationService? _notificationService;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    super.dispose();
  }

  /// Initialize real-time notification listener
  Future<void> _initializeNotifications() async {
    final userId = widget.userId ?? supabase.auth.currentUser?.id;
    final userRole = widget.userRole;

    if (userId != null && userRole != null && mounted) {
      _notificationService = NotificationService();
      _notificationService!.initializeListener(context, userId, userRole);
    }
  }

  /// Logout and navigate to login screen
  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clean medical background
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: MasterLayout.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: widget.title != null
                  ? Text(
                      widget.title!,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
              actions: [
                // Custom actions if provided
                if (widget.actions != null) ...widget.actions!,
                // Logout button for ALL roles
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  tooltip: 'Logout',
                  onPressed: () => _logout(context),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: widget.body,
      bottomNavigationBar: widget.currentIndex >= 0
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  currentIndex: widget.currentIndex,
                  onTap: widget.onNavTap,
                  selectedItemColor: MasterLayout.primaryBlue,
                  unselectedItemColor: Colors.grey.shade400,
                  selectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  items: widget.navItems.map((item) {
                    // We can't easily change the Icon here as it comes from the parent.
                    // But we can ensure the container looks good.
                    return item;
                  }).toList(),
                ),
              ),
            )
          : null,
    );
  }
}
