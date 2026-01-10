import 'dart:async';
import 'package:dentease/clinic/dentease_bills_page.dart';
import 'package:dentease/clinic/dentease_booking_details.dart';
import 'package:dentease/dentist/dentist_patient_details.dart';
import 'package:dentease/staff/staff_rej_can.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffAppointments extends StatefulWidget {
  final String staffId;
  final String clinicId;

  const StaffAppointments({
    super.key,
    required this.staffId,
    required this.clinicId,
  });

  @override
  State<StaffAppointments> createState() => _StaffAppointmentsState();
}

class _StaffAppointmentsState extends State<StaffAppointments>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Approved (Upcoming), Pending (Requests), History (Rejected/Completed)
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Appointments',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Requests'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _StaffBookingList(
              clinicId: widget.clinicId,
              statusFilter: const ['approved'],
              isActionable: true,
              emptyMsg: 'No upcoming appointments',
              icon: Icons.event_available_rounded,
            ),
            _StaffBookingList(
              clinicId: widget.clinicId,
              statusFilter: const ['pending'],
              isRequests: true,
              emptyMsg: 'No pending requests',
              icon: Icons.pending_actions_rounded,
            ),
            _StaffBookingList(
              clinicId: widget.clinicId,
              statusFilter: const ['rejected', 'cancelled', 'completed'],
              emptyMsg: 'No history',
              icon: Icons.history_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic List for Staff Bookings with Stream
class _StaffBookingList extends StatefulWidget {
  final String clinicId;
  final List<String> statusFilter;
  final bool isActionable;
  final bool isRequests;
  final String emptyMsg;
  final IconData icon;

  const _StaffBookingList({
    required this.clinicId,
    required this.statusFilter,
    this.isActionable = false,
    this.isRequests = false,
    required this.emptyMsg,
    required this.icon,
  });

  @override
  State<_StaffBookingList> createState() => _StaffBookingListState();
}

class _StaffBookingListState extends State<_StaffBookingList> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  StreamSubscription? _subscription;
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final offset = _currentPage * _pageSize;
      final data = await supabase
          .from('bookings')
          .select('*')
          .eq('clinic_id', widget.clinicId)
          .inFilter('status', widget.statusFilter)
          .order('date', ascending: false)
          .range(offset, offset + _pageSize - 1);

      if (data.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Enrich with patient and service data
      final enriched = await _enrichBookings(data);

      if (mounted) {
        setState(() {
          _bookings.addAll(enriched);
          _isLoadingMore = false;
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading more bookings: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _subscribe() {
    _subscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .listen(_onData);
  }

  Future<List<Map<String, dynamic>>> _enrichBookings(
      List<Map<String, dynamic>> filtered) async {
    final List<Map<String, dynamic>> enriched = [];

    for (var b in filtered) {
      // Fetch patient via booking relation to bypass potential direct-RLS issues
      final bookingWithPatient = await supabase
          .from('bookings')
          .select('patients(*)')
          .eq('booking_id', b['booking_id'])
          .maybeSingle();

      final p = bookingWithPatient?['patients'];

      final s = await supabase
          .from('services')
          .select()
          .eq('service_id', b['service_id'])
          .maybeSingle();

      enriched.add({
        ...b,
        'patients': p,
        'services': s,
      });
    }

    return enriched;
  }

  Future<void> _onData(List<Map<String, dynamic>> data) async {
    if (!mounted) return;

    // Reset pagination on stream update
    _currentPage = 0;
    _hasMore = true;

    // Filter locally by status
    final filtered = data.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return widget.statusFilter.contains(status);
    }).toList();

    // Sort by date descending
    filtered.sort((a, b) {
      final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(0);
      final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(0);
      return db.compareTo(da); // Newest first
    });

    // Take only first page
    final firstPage = filtered.take(_pageSize).toList();

    // Enrich with patient and service data
    final enriched = await _enrichBookings(firstPage);

    if (mounted) {
      setState(() {
        _bookings = enriched;
        _isLoading = false;
        _hasMore = filtered.length > _pageSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon,
                size: 64, color: AppTheme.textGrey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              widget.emptyMsg,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All appointments will appear here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _bookings.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          );
        }
        return _StaffBookingCard(
          booking: _bookings[index],
          isActionable: widget.isActionable,
          isRequests: widget.isRequests,
          clinicId: widget.clinicId,
        );
      },
    );
  }
}

class _StaffBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isActionable;
  final bool isRequests;
  final String clinicId;

  const _StaffBookingCard({
    required this.booking,
    required this.isActionable,
    required this.isRequests,
    required this.clinicId,
  });

  @override
  Widget build(BuildContext context) {
    final patient = booking['patients'];
    final service = booking['services'];
    final status = (booking['status'] ?? '').toString().toLowerCase();

    final patientName = patient != null
        ? '${patient['firstname']} ${patient['lastname']}'
        : 'Unknown Patient';
    final serviceName = service != null ? service['service_name'] : 'Service';
    final dateStr = booking['date'];
    final date = dateStr != null
        ? DateFormat('MMM d, y • h:mm a').format(DateTime.parse(dateStr))
        : 'No Date';

    final profileUrl = patient?['profile_url'];

    Color statusColor;
    if (status == 'approved') {
      statusColor = AppTheme.successColor;
    } else if (status == 'pending') {
      statusColor = AppTheme.warningColor;
    } else if (status == 'rejected' || status == 'cancelled') {
      statusColor = AppTheme.errorColor;
    } else {
      statusColor = AppTheme.primaryBlue;
    }

    return GestureDetector(
      onTap: () {
        // Navigate to details - but NOT for pending appointments
        if (status == 'rejected' || status == 'cancelled') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      StaffRejectedCancelledBookingsPage(booking: booking)));
        } else if (status != 'pending') {
          // Only allow navigation for approved/completed appointments
          // Use the new DentistPatientDetailsPage for better UI
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DentistPatientDetailsPage(
                      bookingData: booking, clinicId: clinicId)));
        }
        // For pending appointments, do nothing - only buttons should work
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  backgroundImage:
                      profileUrl != null ? NetworkImage(profileUrl) : null,
                  child: profileUrl == null
                      ? Icon(Icons.person_rounded,
                          color: AppTheme.primaryBlue, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          serviceName,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: AppTheme.textGrey),
                          const SizedBox(width: 4),
                          Text(date,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppTheme.textGrey)),
                        ],
                      )
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.5))),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor),
                      ),
                    ),
                    // Arrow indicator for clickable items (not for pending)
                    if (status != 'pending') ...[
                      const SizedBox(height: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textGrey.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
                  ],
                )
              ],
            ),

            // Actions
            if (isActionable && status == 'approved') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BillCalculatorPage(
                                clinicId: clinicId,
                                patientId: booking['patient_id'],
                                bookingId: booking['booking_id'],
                                serviceId: booking['service_id'])));
                  },
                  icon: const Icon(Icons.receipt_long,
                      color: Colors.white, size: 18),
                  label: const Text("Send Billing Now"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            ],

            if (isRequests && status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(context, 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Reject"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(context, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Approve"),
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('bookings').update({'status': newStatus}).eq(
          'booking_id', booking['booking_id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Booking $newStatus")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}
