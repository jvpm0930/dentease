import 'package:dentease/admin/pages/admin_notification_page.dart';
import 'package:dentease/admin/pages/clinics/admin_clinic_details.dart';
import 'package:dentease/admin/pages/clinics/admin_dentease_first.dart';
import 'package:dentease/admin/pages/clinics/admin_dentease_pending.dart';
import 'package:dentease/admin/pages/clinics/admin_rejected_list.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  int approvedClinicsCount = 0;
  int pendingRequestsCount = 0;
  int rejectedClinicsCount = 0; // Changed from totalDentistsCount
  int unreadMessagesCount = 0;
  List<Map<String, dynamic>> recentClinics = [];

  // Modern Medical Theme Colors
  static const kPrimaryBlue = Color(0xFF1134A6);
  static const kTealAccent = Color(0xFF00BFA5);
  static const kBackground = Color(0xFFF8FAFC);
  static const kTextDark = Color(0xFF0D1B2A);
  static const kTextGrey = Color(0xFF5F6C7B);

  @override
  void initState() {
    super.initState();
    debugPrint('📊 [AdminDashboard] Initializing dashboard...');
    _fetchStats();

    // Set up real-time listener for clinic changes
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _clinicSubscription?.unsubscribe();
    super.dispose();
  }

  RealtimeChannel? _clinicSubscription;

  void _setupRealtimeListener() {
    debugPrint('🔄 [AdminDashboard] Setting up real-time listener...');

    _clinicSubscription = supabase
        .channel('admin_dashboard_clinics')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clinics',
          callback: (payload) {
            debugPrint(
                '🔄 [AdminDashboard] Clinic data changed, refreshing stats...');
            _fetchStats();
          },
        )
        .subscribe();
  }

  Future<void> _fetchStats() async {
    debugPrint('🔄 [AdminDashboard] Starting to fetch dashboard stats...');

    final adminId = supabase.auth.currentUser?.id;
    debugPrint('👤 [AdminDashboard] Admin ID: $adminId');

    // Variables to store results
    List<Map<String, dynamic>> approvedList = [];
    int pendingCount = 0;
    int rejectedCount = 0;
    int unreadMsg = 0;

    // 1. Fetch clinic stats and list
    try {
      debugPrint('📡 [AdminDashboard] Fetching clinics...');
      final clinicsResponse = await supabase
          .from('clinics')
          .select(
              'status, created_at, clinic_name, clinic_id, email, profile_url')
          .order('created_at', ascending: false);

      final clinicsList = List<Map<String, dynamic>>.from(clinicsResponse);
      debugPrint(
          '📊 [AdminDashboard] Total clinics fetched: ${clinicsList.length}');

      // Log each clinic for debugging
      for (var clinic in clinicsList) {
        debugPrint(
            '🏥 [AdminDashboard] Clinic: ${clinic['clinic_name']} - Status: ${clinic['status']}');
      }

      approvedList =
          clinicsList.where((c) => c['status'] == 'approved').toList();
      pendingCount = clinicsList.where((c) => c['status'] == 'pending').length;
      rejectedCount =
          clinicsList.where((c) => c['status'] == 'rejected').length;

      debugPrint('✅ [AdminDashboard] Approved clinics: ${approvedList.length}');
      debugPrint('⏳ [AdminDashboard] Pending clinics: $pendingCount');
      debugPrint('❌ [AdminDashboard] Rejected clinics: $rejectedCount');
    } catch (e) {
      debugPrint('❌ [AdminDashboard] Error fetching clinics: $e');
    }

    // 2. Fetch unread messages count
    if (adminId != null) {
      try {
        debugPrint('📡 [AdminDashboard] Fetching unread messages...');
        final msgResponse = await supabase
            .from('supports')
            .count(CountOption.exact)
            .eq('receiver_id', adminId)
            .eq('is_read', false);
        unreadMsg = msgResponse;
        debugPrint('💬 [AdminDashboard] Unread messages: $unreadMsg');
      } catch (e) {
        debugPrint('❌ [AdminDashboard] Error fetching unread messages: $e');
      }
    }

    // Update state
    if (mounted) {
      setState(() {
        approvedClinicsCount = approvedList.length;
        pendingRequestsCount = pendingCount;
        rejectedClinicsCount = rejectedCount;
        unreadMessagesCount = unreadMsg;
        recentClinics = approvedList.take(5).toList();
        isLoading = false;
      });

      debugPrint('🎯 [AdminDashboard] State updated:');
      debugPrint('   - approvedClinicsCount: $approvedClinicsCount');
      debugPrint('   - pendingRequestsCount: $pendingRequestsCount');
      debugPrint('   - rejectedClinicsCount: $rejectedClinicsCount');
      debugPrint('   - unreadMessagesCount: $unreadMessagesCount');
      debugPrint('   - recentClinics: ${recentClinics.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Total notifications = pending requests + unread messages
    final totalNotifications = pendingRequestsCount + unreadMessagesCount;

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: kBackground,
        body: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: kPrimaryBlue))
              : RefreshIndicator(
                  onRefresh: _fetchStats,
                  color: kPrimaryBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Custom Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Dashboard",
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: kTextDark,
                              ),
                            ),
                            Row(
                              children: [
                                // Refresh button
                                IconButton(
                                  onPressed: () {
                                    debugPrint(
                                        '🔄 [AdminDashboard] Manual refresh triggered');
                                    _fetchStats();
                                  },
                                  icon: const Icon(Icons.refresh_outlined,
                                      size: 24, color: kTextDark),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.all(8),
                                    shape: const CircleBorder(),
                                    shadowColor: Colors.black12,
                                    elevation: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Notifications button
                                Stack(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const AdminNotificationPage()),
                                        ).then((_) => _fetchStats());
                                      },
                                      icon: const Icon(
                                          Icons.notifications_outlined,
                                          size: 28,
                                          color: kTextDark),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.all(8),
                                        shape: const CircleBorder(),
                                        shadowColor: Colors.black12,
                                        elevation: 2,
                                      ),
                                    ),
                                    if (totalNotifications > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Center(
                                            child: Text(
                                              totalNotifications > 99
                                                  ? '99+'
                                                  : totalNotifications
                                                      .toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Stats Grid
                        _buildStatsGrid(),

                        const SizedBox(height: 32),

                        // Quick Actions
                        Text(
                          "Quick Actions",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActions(),

                        const SizedBox(height: 32),

                        // Recent Clinics
                        Text(
                          "Recent Approved Clinics",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildRecentClinicsList(),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Approved",
            approvedClinicsCount.toString(),
            Icons.check_circle_outline,
            kTealAccent,
            kTealAccent.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Pending",
            pendingRequestsCount.toString(),
            Icons.hourglass_empty_rounded,
            Colors.orange,
            Colors.orange.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Rejected",
            rejectedClinicsCount.toString(),
            Icons.cancel_outlined,
            Colors.red,
            Colors.red.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: kTextGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    debugPrint(
        '🎯 [AdminDashboard] Building quick actions - pendingRequestsCount: $pendingRequestsCount');
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                "Pending Requests",
                Icons.pending_actions,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const AdminPendingPage(showBackButton: true)),
                  ).then((_) => _fetchStats());
                },
                badge: pendingRequestsCount > 0 ? pendingRequestsCount : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                "Rejected List",
                Icons.cancel_outlined,
                Colors.red,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminRejectedList()),
                  ).then((_) => _fetchStats());
                },
                badge: rejectedClinicsCount > 0 ? rejectedClinicsCount : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                "Approved Clinics",
                Icons.check_circle_outline,
                kTealAccent,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminClinicListPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                "Featured Clinics",
                Icons.star_outline_rounded,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const AdminClinicListPage(showFeaturedOnly: true),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap,
      {int? badge}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 99 ? '99+' : badge.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentClinicsList() {
    if (recentClinics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.business_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              "No approved clinics yet",
              style: GoogleFonts.poppins(color: kTextGrey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: recentClinics.map((clinic) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: kPrimaryBlue.withValues(alpha: 0.1),
              backgroundImage: clinic['profile_url'] != null
                  ? NetworkImage(clinic['profile_url'])
                  : null,
              child: clinic['profile_url'] == null
                  ? const Icon(Icons.local_hospital, color: kPrimaryBlue)
                  : null,
            ),
            title: Text(
              clinic['clinic_name'] ?? 'Unknown',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 15, color: kTextDark),
            ),
            subtitle: Text(
              clinic['email'] ?? '',
              style: GoogleFonts.roboto(fontSize: 13, color: kTextGrey),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: kTextGrey),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdmClinicDetailsPage(
                    clinicId: clinic['clinic_id'],
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
