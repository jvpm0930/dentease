import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:dentease/dentist/dentist_patient_details.dart';
import 'package:dentease/clinic/dentease_bills_page.dart';

/// Dentist Patients Page with Pending/Completed Tabs
class DentistPatientsPage extends StatefulWidget {
  final String clinicId;

  const DentistPatientsPage({super.key, required this.clinicId});

  @override
  State<DentistPatientsPage> createState() => _DentistPatientsPageState();
}

class _DentistPatientsPageState extends State<DentistPatientsPage>
    with SingleTickerProviderStateMixin {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  late TabController _tabController;

  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue
  static const kBackground = Color(0xFFF8FAFC); // Clean medical background

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: kPrimaryBlue, // Professional blue header
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: const BackButton(color: Colors.white),
          title: Text(
            'My Patients',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            tabs: const [
              Tab(text: 'Pending Patients'),
              Tab(text: 'Completed History'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _PendingPatientsTab(clinicId: widget.clinicId),
            _CompletedHistoryTab(clinicId: widget.clinicId),
          ],
        ),
      ),
    );
  }
}

/// Pending Patients Tab (Active/Upcoming) with Real-time Updates
class _PendingPatientsTab extends StatefulWidget {
  final String clinicId;

  const _PendingPatientsTab({required this.clinicId});

  @override
  State<_PendingPatientsTab> createState() => _PendingPatientsTabState();
}

class _PendingPatientsTabState extends State<_PendingPatientsTab> {
  final supabase = Supabase.instance.client;
  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue

  List<Map<String, dynamic>> _sortedBookings = [];
  bool _isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _startRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Start real-time subscription for booking updates
  void _startRealtimeSubscription() {
    _subscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .listen((data) {
          _processBookings(data);
        });
  }

  /// Process bookings from stream and fetch details
  Future<void> _processBookings(List<Map<String, dynamic>> allBookings) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Filter for non-completed statuses
      final pendingBookings = allBookings.where((b) {
        final status = (b['status'] ?? 'pending').toString().toLowerCase();
        return status != 'completed' &&
            status != 'rejected' &&
            status != 'cancelled';
      }).toList();

      // Fetch details for each booking and sort
      final List<Map<String, dynamic>> bookingsWithDetails = [];
      for (var booking in pendingBookings) {
        final details = await _fetchBookingDetails(booking);
        bookingsWithDetails.add(details);
      }

      // Sort by patient name (firstname, then lastname)
      bookingsWithDetails.sort((a, b) {
        final patientA = a['patient'] as Map<String, dynamic>?;
        final patientB = b['patient'] as Map<String, dynamic>?;

        final nameA =
            '${patientA?['firstname'] ?? ''} ${patientA?['lastname'] ?? ''}'
                .trim()
                .toLowerCase();
        final nameB =
            '${patientB?['firstname'] ?? ''} ${patientB?['lastname'] ?? ''}'
                .trim()
                .toLowerCase();

        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _sortedBookings = bookingsWithDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error processing bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchBookingDetails(
      Map<String, dynamic> booking) async {
    final patient = await supabase
        .from('patients')
        .select('firstname, lastname, profile_url')
        .eq('patient_id', booking['patient_id'])
        .maybeSingle();

    final service = await supabase
        .from('services')
        .select('service_name, service_detail')
        .eq('service_id', booking['service_id'])
        .maybeSingle();

    return {
      ...booking,
      'patient': patient,
      'service': service,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryBlue),
      );
    }

    if (_sortedBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No pending patients',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger reload by re-subscribing
        _subscription?.cancel();
        _startRealtimeSubscription();
      },
      color: kPrimaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sortedBookings.length,
        itemBuilder: (context, index) {
          return _MedicalCard(
            bookingData: _sortedBookings[index],
            isPending: true,
            clinicId: widget.clinicId,
          );
        },
      ),
    );
  }
}

/// Completed History Tab (Completed Appointments) with Real-time Updates
class _CompletedHistoryTab extends StatefulWidget {
  final String clinicId;

  const _CompletedHistoryTab({required this.clinicId});

  @override
  State<_CompletedHistoryTab> createState() => _CompletedHistoryTabState();
}

class _CompletedHistoryTabState extends State<_CompletedHistoryTab> {
  final supabase = Supabase.instance.client;
  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue

  List<Map<String, dynamic>> _sortedBookings = [];
  bool _isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _startRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Start real-time subscription for booking updates
  void _startRealtimeSubscription() {
    _subscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .listen((data) {
          _processBookings(data);
        });
  }

  /// Process bookings from stream and fetch details
  Future<void> _processBookings(List<Map<String, dynamic>> allBookings) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Filter for completed statuses
      final completedBookings = allBookings.where((b) {
        final status = (b['status'] ?? '').toString().toLowerCase();
        return status == 'completed';
      }).toList();

      // Fetch details for each booking and sort
      final List<Map<String, dynamic>> bookingsWithDetails = [];
      for (var booking in completedBookings) {
        final details = await _fetchBookingDetails(booking);
        bookingsWithDetails.add(details);
      }

      // Sort by patient name (firstname, then lastname)
      bookingsWithDetails.sort((a, b) {
        final patientA = a['patient'] as Map<String, dynamic>?;
        final patientB = b['patient'] as Map<String, dynamic>?;

        final nameA =
            '${patientA?['firstname'] ?? ''} ${patientA?['lastname'] ?? ''}'
                .trim()
                .toLowerCase();
        final nameB =
            '${patientB?['firstname'] ?? ''} ${patientB?['lastname'] ?? ''}'
                .trim()
                .toLowerCase();

        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _sortedBookings = bookingsWithDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error processing bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchBookingDetails(
      Map<String, dynamic> booking) async {
    final patient = await supabase
        .from('patients')
        .select('firstname, lastname, profile_url')
        .eq('patient_id', booking['patient_id'])
        .maybeSingle();

    final service = await supabase
        .from('services')
        .select('service_name, service_detail')
        .eq('service_id', booking['service_id'])
        .maybeSingle();

    return {
      ...booking,
      'patient': patient,
      'service': service,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryBlue),
      );
    }

    if (_sortedBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No completed history',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _subscription?.cancel();
        _startRealtimeSubscription();
      },
      color: kPrimaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sortedBookings.length,
        itemBuilder: (context, index) {
          return _MedicalCard(
            bookingData: _sortedBookings[index],
            isPending: false,
            clinicId: widget.clinicId,
          );
        },
      ),
    );
  }
}

/// Medical Card Component
class _MedicalCard extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final bool isPending;
  final String clinicId;

  const _MedicalCard({
    required this.bookingData,
    required this.isPending,
    required this.clinicId,
  });

  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue

  Future<void> _markAsCompleted(BuildContext context) async {
    // Navigate to Bill Calculator Page for billing and completion
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillCalculatorPage(
          clinicId: clinicId,
          patientId: bookingData['patient_id'],
          bookingId: bookingData['booking_id'],
          serviceId: bookingData['service_id'],
        ),
      ),
    );
    // No need to manually update status, the Bill Page does it.
    // The stream listener in the parent widget will automatically pick up the change.
  }

  @override
  Widget build(BuildContext context) {
    final patient = bookingData['patient'] as Map<String, dynamic>?;
    final service = bookingData['service'] as Map<String, dynamic>?;

    final patientName =
        '${patient?['firstname'] ?? 'Unknown'} ${patient?['lastname'] ?? ''}'
            .trim();
    final serviceName = service?['service_name'] ?? 'Service';
    final serviceDetail = service?['service_detail'] ?? '';
    final profileUrl = patient?['profile_url'] as String?;
    // Use 'date' field to match the database schema
    final appointmentDate =
        (bookingData['appointment_date'] ?? bookingData['date']) as String?;
    final status = bookingData['status'] ?? 'pending';

    final dateFormatted = appointmentDate != null
        ? DateFormat('MMM d, yyyy • h:mm a')
            .format(DateTime.parse(appointmentDate))
        : 'No date';

    // Status color
    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved':
      case 'accepted':
        statusColor = Colors.green.shade600;
        statusText = 'Approved';
        break;
      case 'pending':
        statusColor = Colors.orange.shade600;
        statusText = 'Pending request';
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusText = 'Rejected';
        break;
      case 'completed':
        statusColor = Colors.blue.shade600;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusText = status.toUpperCase();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DentistPatientDetailsPage(
              bookingData: bookingData,
              clinicId: clinicId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Patient Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: kPrimaryBlue.withValues(alpha: 0.1),
                  backgroundImage:
                      profileUrl != null ? NetworkImage(profileUrl) : null,
                  child: profileUrl == null
                      ? const Icon(Icons.person, size: 30, color: kPrimaryBlue)
                      : null,
                ),
                const SizedBox(width: 16),
                // Patient Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Condition Tag (Service Name)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          serviceName,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: kPrimaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Appointment Date
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            dateFormatted,
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge and Arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey.shade400),
                  ],
                ),
              ],
            ),
            if (serviceDetail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Treatment Needed: $serviceDetail",
                  style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (isPending &&
                (status == 'approved' || status == 'accepted')) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsCompleted(context),
                  icon: const Icon(Icons.receipt_long,
                      color: Colors.white, size: 18),
                  label: const Text("Send Billing Now"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
