import 'package:dentease/clinic/deantease_analytics.dart';
import 'package:dentease/common/navigation_helper.dart';
import 'package:dentease/dentist/dentist_clinic_sched.dart';
import 'package:dentease/dentist/dentist_clinic_services.dart';
import 'package:dentease/dentist/dentist_patients.dart';
import 'package:dentease/dentist/dentist_staff_list.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistPage extends StatefulWidget {
  final String clinicId;
  final String dentistId;
  final Function(int) onTabChange;

  const DentistPage({
    super.key,
    required this.clinicId,
    required this.dentistId,
    required this.onTabChange,
  });

  @override
  _DentistPageState createState() => _DentistPageState();
}

class _DentistPageState extends State<DentistPage> {
  final supabase = Supabase.instance.client;

  String? dentistFirstname;
  String? clinicName;
  int todayPatients = 0; // Today's approved appointments
  int pendingRequests = 0; // Pending requests count
  int upcomingPatients = 0; // Approved but upcoming appointments
  int totalCompleted = 0; // Total completed patients
  bool isLoading = true;
  RealtimeChannel? _bookingsChannel;
  int unreadMessagesCount = 0;
  String? latestMessageSender;
  String? latestMessageContent;

  // Professional Blue Medical Theme Colors
  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue
  static const kAccentBlue = Color(0xFF0D2A7A); // Accent Blue
  static const kSoftBlue = Color(0xFFE3F2FD); // Soft Blue backgrounds
  static const kTealAccent = Color(0xFF00BFA5); // Success states
  static const kTextDark = Color(0xFF0D1B2A); // Primary text
  static const kTextGrey = Color(0xFF5F6C7B); // Secondary text

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _bookingsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeListener() {
    // Listen for any booking changes in this clinic for real-time updates
    _bookingsChannel = supabase
        .channel('dashboard_bookings_${widget.clinicId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clinic_id',
            value: widget.clinicId,
          ),
          callback: (payload) {
            // Refresh dashboard data when any booking changes
            _fetchDashboardData();
          },
        )
        .subscribe();
  }

  Future<void> _fetchDashboardData() async {
    try {
      // Fetch dentist details
      final dentistResponse = await supabase
          .from('dentists')
          .select('firstname')
          .eq('dentist_id', widget.dentistId)
          .maybeSingle();

      if (dentistResponse != null) {
        dentistFirstname = dentistResponse['firstname'];
      }

      // Fetch clinic name
      final clinicResponse = await supabase
          .from('clinics')
          .select('clinic_name')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (clinicResponse != null) {
        clinicName = clinicResponse['clinic_name'];
      }

      // Fetch today's approved patients (ready to be seen today)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Use 'date' field which matches the database schema
      final todayBookings = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'approved')
          .gte('date', startOfDay.toIso8601String())
          .lt('date', endOfDay.toIso8601String());

      todayPatients = (todayBookings as List).length;

      // Fetch pending requests (new appointment requests awaiting approval)
      final pendingBookings = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'pending');

      pendingRequests = (pendingBookings as List).length;

      // Fetch upcoming patients (approved but not yet completed)
      final upcomingBookings = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'approved');

      upcomingPatients = (upcomingBookings as List).length;

      // Total Completed Patients (unique patients with completed appointments)
      final completedResponse = await supabase
          .from('bookings')
          .select('patient_id')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'completed');

      // Get unique count
      final uniquePatients =
          completedResponse.map((e) => e['patient_id']).toSet();
      totalCompleted = uniquePatients.length;

      // Fetch unread messages count for this dentist
      final dentistAuthId = supabase.auth.currentUser?.id;
      if (dentistAuthId != null) {
        final participantsData = await supabase
            .from('conversation_participants')
            .select('unread_count, conversation_id')
            .eq('user_id', dentistAuthId);

        unreadMessagesCount = participantsData.fold<int>(
            0, (sum, p) => sum + ((p['unread_count'] as int?) ?? 0));

        // Get latest unread message if any
        if (unreadMessagesCount > 0 && participantsData.isNotEmpty) {
          final convId = participantsData.first['conversation_id'];
          final latestMsg = await supabase
              .from('messages')
              .select('sender_name, content')
              .eq('conversation_id', convId)
              .neq('sender_id', dentistAuthId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (latestMsg != null) {
            latestMessageSender = latestMsg['sender_name'];
            latestMessageContent = latestMsg['content'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clean medical background
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : RefreshIndicator(
              color: kPrimaryBlue,
              onRefresh: _fetchDashboardData,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Unread Message Banner (like patient side)
                          if (unreadMessagesCount > 0) _buildMessageBanner(),

                          // Stats
                          _buildSectionTitle("Overview"),
                          const SizedBox(height: 16),
                          _buildStatsRow(),

                          const SizedBox(height: 32),

                          // Quick Actions Grid
                          _buildSectionTitle("Quick Actions"),
                          const SizedBox(height: 16),
                          _buildQuickActionsGrid(),

                          const SizedBox(height: 100), // Bottom padding
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: kPrimaryBlue, // Professional blue header
      foregroundColor: Colors.white,
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          "Dashboard",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            color: kPrimaryBlue,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.notifications_none_rounded,
                color: Colors.white),
          ),
        )
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: kTextDark,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Pending Requests",
                value: pendingRequests.toString(),
                icon: Icons.pending_actions_rounded,
                color: Colors.orange,
                bgColor: Colors.orange.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: "Today's Patients",
                value: todayPatients.toString(),
                icon: Icons.calendar_today_rounded,
                color: kPrimaryBlue,
                bgColor: kSoftBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Upcoming",
                value: upcomingPatients.toString(),
                icon: Icons.event_available_rounded,
                color: kTealAccent,
                bgColor: kTealAccent.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: "Total Completed",
                value: totalCompleted.toString(),
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                bgColor: Colors.green.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
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

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildActionCard(
          "My Patients",
          Icons.people_alt_rounded,
          kTealAccent,
          () =>
              safePush(context, DentistPatientsPage(clinicId: widget.clinicId)),
        ),
        _buildActionCard(
          "Services",
          Icons.medical_services_rounded,
          kAccentBlue, // Use accent blue for medical services
          () =>
              safePush(context, DentistServListPage(clinicId: widget.clinicId)),
        ),
        _buildActionCard(
          "Staff", // Restored Staff Section
          Icons.badge_rounded,
          kPrimaryBlue, // Use primary blue for staff
          () => safePush(context, DentStaffListPage(clinicId: widget.clinicId)),
        ),
        _buildActionCard(
          "Schedule", // Restored Clinic Schedule
          Icons.access_time_filled_rounded,
          kAccentBlue, // Use accent blue for schedule
          () => safePush(
              context, DentistClinicSchedPage(clinicId: widget.clinicId)),
        ),
        _buildActionCard(
          "Analytics",
          Icons.analytics_rounded,
          kTealAccent, // Use teal for analytics
          () => safePush(context, ClinicAnalytics(clinicId: widget.clinicId)),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBanner() {
    return GestureDetector(
      onTap: () {
        // Navigate to chat tab
        widget.onTabChange(2); // Assuming chat is at index 2
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message from ${latestMessageSender ?? "Patient"}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latestMessageContent ?? 'You have new messages',
                    style: GoogleFonts.roboto(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'View',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF9C27B0),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
