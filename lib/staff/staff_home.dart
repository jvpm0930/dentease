import 'dart:async';
import 'package:dentease/common/navigation_helper.dart';
import 'package:dentease/dentist/dentist_clinic_services.dart';
import 'package:dentease/staff/staff_clinic_sched.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffHomePage extends StatefulWidget {
  final String clinicId;
  final String staffId;

  const StaffHomePage({
    super.key,
    required this.clinicId,
    required this.staffId,
  });

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  String? firstname;
  String? lastname;
  String? profileUrl;
  String? clinicName;
  String? dentistName;
  String? dentistSpecialty;
  int todayBookings = 0;
  int pendingBookings = 0;
  bool isLoading = true;

  // Real-time subscription for pending bookings
  StreamSubscription? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _subscribeToBookings();
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToBookings() {
    debugPrint('📡 [StaffHome] Starting booking subscription...');
    _bookingSubscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .listen((data) {
          if (mounted) {
            final today = DateTime.now();
            final startOfDay = DateTime(today.year, today.month, today.day);
            final endOfDay = startOfDay.add(const Duration(days: 1));

            final todayCount = data.where((b) {
              final status = b['status']?.toString().toLowerCase();
              final dateStr = b['date'];
              if (dateStr == null || status != 'approved') return false;
              final date = DateTime.tryParse(dateStr);
              if (date == null) return false;
              return date.isAfter(startOfDay) && date.isBefore(endOfDay);
            }).length;

            final pendingCount =
                data.where((b) => b['status'] == 'pending').length;

            debugPrint(
                '📅 [StaffHome] Today: $todayCount, Pending: $pendingCount');
            setState(() {
              todayBookings = todayCount;
              pendingBookings = pendingCount;
            });
          }
        });
  }

  Future<void> _fetchData() async {
    try {
      // Fetch staff profile
      final staffData = await supabase
          .from('staffs')
          .select('firstname, lastname, profile_url')
          .eq('staff_id', widget.staffId)
          .maybeSingle();

      if (staffData != null) {
        firstname = staffData['firstname'];
        lastname = staffData['lastname'];
        final url = staffData['profile_url'];
        profileUrl = url != null && url.isNotEmpty
            ? '$url?t=${DateTime.now().millisecondsSinceEpoch}'
            : null;
      }

      // Fetch clinic name and dentist info
      final clinicData = await supabase
          .from('clinics')
          .select('clinic_name, owner_id')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (clinicData != null) {
        clinicName = clinicData['clinic_name'];

        // Fetch dentist details using owner_id
        debugPrint('Fetching dentist data (no specialty)...');
        Map<String, dynamic>? dentistData;

        if (clinicData['owner_id'] != null) {
          debugPrint('Running Query 1 (owner_id)...');
          try {
            dentistData = await supabase
                .from('dentists')
                .select('firstname, lastname') // Query restored
                .eq('dentist_id', clinicData['owner_id'])
                .maybeSingle();
          } catch (e) {
            debugPrint('QUERY 1 FAILED (Likely RLS/Schema issue): $e');
            dentistData = null;
          }
        }

        // Fallback: If no owner found or owner_id was null, try finding ANY dentist in the clinic
        if (dentistData == null) {
          debugPrint('Running Query 2 (fallback)...');
          try {
            dentistData = await supabase
                .from('dentists')
                .select('firstname, lastname') // Query restored
                .eq('clinic_id', widget.clinicId)
                .limit(1)
                .maybeSingle();
          } catch (e) {
            debugPrint('Fallback Query Failed: $e');
            dentistData = null;
          }
        }

        if (dentistData != null) {
          dentistName =
              '${dentistData['firstname']} ${dentistData['lastname']}';
          dentistSpecialty =
              'General Dentist'; // Default fallback since column missing
        }
      }

      // Fetch today's bookings
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todayData = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'approved')
          .gte('date', startOfDay.toIso8601String())
          .lt('date', endOfDay.toIso8601String());

      todayBookings = todayData.length;

      // Fetch pending bookings - FIXED: use 'date' column not 'appointment_date'
      final pendingData = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'pending');

      pendingBookings = pendingData.length;

    } catch (e) {
      debugPrint('Error fetching staff data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
            : RefreshIndicator(
                color: AppTheme.primaryBlue,
                onRefresh: _fetchData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                        child: _buildWelcomeHeader(),
                      ),

                      // Quick Stats
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildQuickStats(),
                      ),

                      const SizedBox(height: 30),

                      // Dentist Information Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildDentistSection(),
                      ),

                      const SizedBox(height: 30),

                      // Quick Actions Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Actions',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildQuickActionsList(),
                          ],
                        ),
                      ),

                      const SizedBox(
                          height: 100), // Bottom padding for navigation
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final fullName = '${firstname ?? ''} ${lastname ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage:
                profileUrl != null ? NetworkImage(profileUrl!) : null,
            child: profileUrl == null
                ? const Icon(Icons.person_rounded,
                    size: 32, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  fullName.isNotEmpty ? fullName : 'Staff',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (clinicName != null)
                  Text(
                    clinicName!,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Today',
            value: todayBookings.toString(),
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF34C759),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Pending',
            value: pendingBookings.toString(),
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFFF9500),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor,
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDentistSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor,
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Working Under',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      dentistName ?? 'Dr. Unknown',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dentistSpecialty != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                dentistSpecialty!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsList() {
    return Column(
      children: [
        _buildActionTile(
          title: 'View Services',
          subtitle: 'Check clinic services and pricing',
          icon: Icons.medical_services_rounded,
          color: AppTheme.primaryBlue,
          onTap: () => safePush(
            context,
            DentistServListPage(clinicId: widget.clinicId),
          ),
        ),
        _buildActionTile(
          title: 'Manage Schedule',
          subtitle: 'Set clinic operating hours',
          icon: Icons.access_time_filled_rounded,
          color: const Color(0xFF0D2A7A),
          onTap: () => safePush(
            context,
            StaffClinicSchedPage(clinicId: widget.clinicId),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.dividerColor,
            width: 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textGrey.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
