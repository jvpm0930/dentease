import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Appointment Manager - Replaces Schedule tab
/// Kanban-style view: Requests | Upcoming | Cancelled
class DentistAppointmentsPage extends StatefulWidget {
  final String clinicId;

  const DentistAppointmentsPage({super.key, required this.clinicId});

  @override
  State<DentistAppointmentsPage> createState() =>
      _DentistAppointmentsPageState();
}

class _DentistAppointmentsPageState extends State<DentistAppointmentsPage>
    with SingleTickerProviderStateMixin {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  late TabController _tabController;
  RealtimeChannel? _bookingsChannel;

  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue
  static const kAccentBlue = Color(0xFF0D2A7A); // Accent Blue
  static const kBackground = Color(0xFFF8FAFC); // Clean medical background
  static const kRed = Color(0xFFD32F2F); // Error red

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _bookingsChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  void _setupRealtimeListener() {
    // Listen for booking changes to update counts in real-time
    _bookingsChannel = supabase
        .channel('appointments_${widget.clinicId}')
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
            // Force rebuild to update counts
            if (mounted) setState(() {});
          },
        )
        .subscribe();
  }

  Stream<int> _getPendingCountStream() {
    debugPrint(
        'DEBUG: [Dentist] Getting pending count for clinic: ${widget.clinicId}');
    return supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .map((bookings) {
          debugPrint(
              'DEBUG: [Dentist] Raw bookings stream: ${bookings.length} total bookings');
          debugPrint('DEBUG: [Dentist] All bookings: $bookings');
          final pendingCount = bookings
              .where((booking) => booking['status'] == 'pending')
              .length;
          debugPrint('DEBUG: [Dentist] Pending count: $pendingCount');
          return pendingCount;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue, // Professional blue header
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Appointments',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: StreamBuilder<int>(
                stream: _getPendingCountStream(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Requests'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Tab(text: 'Upcoming'),
            const Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestsTab(clinicId: widget.clinicId),
          _UpcomingTab(clinicId: widget.clinicId),
          _CancelledTab(clinicId: widget.clinicId),
        ],
      ),
    );
  }
}

/// Requests Tab - Pending bookings with Accept/Reject buttons
class _RequestsTab extends StatefulWidget {
  final String clinicId;

  const _RequestsTab({
    required this.clinicId,
  });

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('bookings').stream(primaryKey: ['booking_id']).map(
          (bookings) => bookings
              .where((b) => b['clinic_id'] == widget.clinicId)
              .where((b) => b['status'] == 'pending')
              .toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryBlue),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _RequestCard(
              booking: booking,
              onApprove: () => _approveBooking(supabase, booking['booking_id']),
              onReject: () => _rejectBooking(supabase, booking['booking_id']),
            );
          },
        );
      },
    );
  }

  Future<void> _approveBooking(
      SupabaseClient supabase, String bookingId) async {
    try {
      debugPrint('DEBUG: Approving booking: $bookingId');
      await supabase
          .from('bookings')
          .update({'status': 'approved'}).eq('booking_id', bookingId);
      debugPrint('DEBUG: Booking approved successfully');

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment approved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving appointment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _rejectBooking(SupabaseClient supabase, String bookingId) async {
    try {
      debugPrint('DEBUG: Rejecting booking: $bookingId');
      await supabase
          .from('bookings')
          .update({'status': 'rejected'}).eq('booking_id', bookingId);
      debugPrint('DEBUG: Booking rejected successfully');

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rejected'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting appointment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// Request Card Widget
class _RequestCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.booking,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  String? patientName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatientInfo();
  }

  Future<void> _fetchPatientInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final patientId = widget.booking['patient_id'];

      if (patientId != null) {
        final response = await supabase
            .from('patients')
            .select('firstname, lastname')
            .eq('patient_id', patientId)
            .single();

        setState(() {
          patientName =
              '${response['firstname'] ?? ''} ${response['lastname'] ?? ''}'
                  .trim();
          if (patientName!.isEmpty) patientName = 'Unknown Patient';
          isLoading = false;
        });
      } else {
        setState(() {
          patientName = 'Unknown Patient';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching patient info: $e');
      setState(() {
        patientName = 'Unknown Patient';
        isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No date';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'No time';
    try {
      // Handle both time formats: "13:30" and full datetime
      if (timeStr.contains('T')) {
        final dateTime = DateTime.parse(timeStr);
        return DateFormat('h:mm a').format(dateTime);
      } else {
        // Parse time string like "13:30"
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final time = DateTime(2000, 1, 1, hour, minute);
          return DateFormat('h:mm a').format(time);
        }
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentDate = widget.booking['date'] as String?;
    final appointmentTime = widget.booking['start_time'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1134A6)
                      .withValues(alpha: 0.1), // Primary blue background
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF1134A6), // Primary blue icon
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoading
                            ? 'Loading...'
                            : (patientName ?? 'Unknown Patient'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Appointment Request',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(appointmentDate),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatTime(appointmentTime),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32), // Success green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Accept', style: GoogleFonts.poppins()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F), // Error red
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Reject', style: GoogleFonts.poppins()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Upcoming Tab - Approved future appointments
class _UpcomingTab extends StatelessWidget {
  final String clinicId;

  const _UpcomingTab({required this.clinicId});

  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('bookings').stream(primaryKey: ['booking_id']).map(
          (bookings) => bookings
              .where((b) => b['clinic_id'] == clinicId)
              .where((b) => b['status'] == 'approved')
              .toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryBlue),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No upcoming appointments',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _AppointmentCard(booking: booking);
          },
        );
      },
    );
  }
}

/// Cancelled Tab - Cancelled/Rejected appointments
class _CancelledTab extends StatelessWidget {
  final String clinicId;

  const _CancelledTab({required this.clinicId});

  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.client
          .from('bookings')
          .stream(primaryKey: ['booking_id']).map((bookings) => bookings
              .where((b) => b['clinic_id'] == clinicId)
              .where((b) => ['cancelled', 'rejected'].contains(b['status']))
              .toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryBlue),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No cancelled appointments',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _AppointmentCard(booking: booking);
          },
        );
      },
    );
  }
}

/// Appointment Card - For Upcoming and Cancelled tabs
class _AppointmentCard extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _AppointmentCard({required this.booking});

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  String? patientName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatientInfo();
  }

  Future<void> _fetchPatientInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final patientId = widget.booking['patient_id'];

      if (patientId != null) {
        final response = await supabase
            .from('patients')
            .select('firstname, lastname')
            .eq('patient_id', patientId)
            .single();

        setState(() {
          patientName =
              '${response['firstname'] ?? ''} ${response['lastname'] ?? ''}'
                  .trim();
          if (patientName!.isEmpty) patientName = 'Unknown Patient';
          isLoading = false;
        });
      } else {
        setState(() {
          patientName = 'Unknown Patient';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching patient info: $e');
      setState(() {
        patientName = 'Unknown Patient';
        isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No date';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'No time';
    try {
      // Handle both time formats: "13:30" and full datetime
      if (timeStr.contains('T')) {
        final dateTime = DateTime.parse(timeStr);
        return DateFormat('h:mm a').format(dateTime);
      } else {
        // Parse time string like "13:30"
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final time = DateTime(2000, 1, 1, hour, minute);
          return DateFormat('h:mm a').format(time);
        }
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentDate = widget.booking['date'] as String?;
    final appointmentTime = widget.booking['start_time'] as String?;
    final status = widget.booking['status'] as String?;

    Color statusColor = Colors.grey;
    if (status == 'approved') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;
    if (status == 'cancelled') statusColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoading
                            ? 'Loading...'
                            : (patientName ?? 'Unknown Patient'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        status?.toUpperCase() ?? 'UNKNOWN',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(appointmentDate),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatTime(appointmentTime),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
