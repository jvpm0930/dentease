import 'package:dentease/widgets/clinicWidgets/clinic_slider.dart';
import 'package:dentease/widgets/clinicWidgets/nearbyClinic.dart';
import 'package:dentease/patients/clinic_list_page.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientHomePage extends StatefulWidget {
  final String patientId;

  const PatientHomePage({super.key, required this.patientId});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  String? firstname;
  String? lastname;
  String? profileUrl;
  int upcomingBookings = 0;
  int completedBookings = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    debugPrint('🔄 [PatientHome] Fetching dashboard data...');
    try {
      // Fetch patient profile
      debugPrint(
          '👤 [PatientHome] Fetching patient profile for ID: ${widget.patientId}');
      final profileData = await supabase
          .from('patients')
          .select('firstname, lastname, profile_url')
          .eq('patient_id', widget.patientId)
          .maybeSingle();

      if (profileData != null) {
        firstname = profileData['firstname'];
        lastname = profileData['lastname'];
        final url = profileData['profile_url'];
        profileUrl = url != null && url.isNotEmpty
            ? '$url?t=${DateTime.now().millisecondsSinceEpoch}'
            : null;
        debugPrint('✅ [PatientHome] Profile loaded: $firstname $lastname');
      } else {
        debugPrint('⚠️ [PatientHome] No profile data found!');
      }

      // Fetch upcoming bookings count
      debugPrint('📅 [PatientHome] Fetching upcoming bookings...');
      final upcomingData = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('patient_id', widget.patientId)
          .inFilter('status', ['approved', 'pending']);

      upcomingBookings = upcomingData.length;
      debugPrint('✅ [PatientHome] Upcoming bookings: $upcomingBookings');

      // Fetch completed bookings count
      debugPrint('✅ [PatientHome] Fetching completed bookings...');
      final completedData = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('patient_id', widget.patientId)
          .eq('status', 'completed');

      completedBookings = completedData.length;
      debugPrint('✅ [PatientHome] Completed bookings: $completedBookings');
    } catch (e) {
      debugPrint('❌ [PatientHome] Error fetching patient data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    profileUrl != null ? NetworkImage(profileUrl!) : null,
                child: profileUrl == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    _getDisplayName(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : RefreshIndicator(
              color: AppTheme.primaryBlue,
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats Cards
                    Text(
                      'Your Health Overview',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildStatCard(
                          'Upcoming',
                          '$upcomingBookings',
                          'Appointments',
                          Icons.schedule_rounded,
                          AppTheme.warningColor,
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildStatCard(
                          'Completed',
                          '$completedBookings',
                          'Treatments',
                          Icons.check_circle_rounded,
                          AppTheme.tealAccent,
                        )),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildActionCard(
                          'Find Nearby',
                          'Clinics',
                          Icons.location_on_rounded,
                          AppTheme.primaryBlue,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClinicMapPage(),
                              )),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildActionCard(
                          'Browse All',
                          'Clinics',
                          Icons.list_alt_rounded,
                          AppTheme.tealAccent,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClinicListPage(),
                              )),
                        )),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Featured Clinics Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Featured Clinics',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClinicListPage(),
                              )),
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      height: 280,
                      child: ClinicCarousel(),
                    ),

                    const SizedBox(height: 100), // Bottom spacing for nav bar
                  ],
                ),
              ),
            ),
    );
  }

  String _getDisplayName() {
    final fullName = '${firstname ?? ''} ${lastname ?? ''}'.trim();
    return fullName.isNotEmpty ? fullName : 'Patient';
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
