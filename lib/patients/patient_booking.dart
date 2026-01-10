import 'dart:async';
import 'package:dentease/patients/patient_bookingSuccess.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:dentease/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class PatientBookingPage extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String servicePrice;
  final String serviceDetail;
  final String clinicId;

  const PatientBookingPage({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceDetail,
    required this.clinicId,
  });

  @override
  _PatientBookingPageState createState() => _PatientBookingPageState();
}

class _PatientBookingPageState extends State<PatientBookingPage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  DateTime selectedDate = DateTime.now();
  CalendarFormat calendarFormat = CalendarFormat.month;
  bool isBooking = false;
  String? errorMessage;

  List<String> availableSlots =
      []; // Changed from List<int> to List<String> for 30-min slots
  List<String> bookedSlots = []; // Changed from List<int> to List<String>
  String?
      selectedSlot; // Changed from int? selectedHour to String? selectedSlot

  @override
  void initState() {
    super.initState();
    _fetchAvailableSlots();
    _setupBookingStatusListener();
  }

  @override
  void dispose() {
    _bookingStatusSubscription?.cancel();
    super.dispose();
  }

  StreamSubscription? _bookingStatusSubscription;

  // Listen for booking status changes to update slot availability in real-time
  void _setupBookingStatusListener() {
    _bookingStatusSubscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id']).listen((data) {
      // Filter for relevant bookings and refresh slots
      final relevantBookings = data.where((booking) =>
          booking['clinic_id'] == widget.clinicId &&
          booking['service_id'] == widget.serviceId);

      if (relevantBookings.isNotEmpty && mounted) {
        _fetchAvailableSlots();
      }
    });
  }

  // Generate time slots based on interval
  // intervalMinutes: 30 for Pinoy Hustler, 60 for all other patterns (Standard, Mall Clinic, etc.)
  List<String> _generateTimeSlots(int startHour, int endHour,
      {int intervalMinutes = 60}) {
    List<String> slots = [];
    int currentMinutes = startHour * 60;
    final endMinutes = endHour * 60;

    while (currentMinutes < endMinutes) {
      final hour = currentMinutes ~/ 60;
      final minute = currentMinutes % 60;
      slots.add(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      currentMinutes += intervalMinutes;
    }
    return slots;
  }

  // Convert time slot string to minutes for comparison (e.g., "10:30" -> 630)
  int _timeSlotToMinutes(String timeSlot) {
    final parts = timeSlot.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  // Convert 24-hour time format to AM-PM format (e.g., "10:30" -> "10:30 AM", "14:30" -> "2:30 PM")
  String _formatTimeSlotToAmPm(String timeSlot) {
    final parts = timeSlot.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$displayHour:$displayMinute $period';
  }

  // Get appropriate message when no slots are available
  String _getNoSlotsMessage() {
    final now = DateTime.now();
    final isPastDate =
        selectedDate.isBefore(DateTime(now.year, now.month, now.day));

    if (isPastDate) {
      return "Past date selected";
    } else {
      return "No available slots for this date";
    }
  }

  // Get appropriate description when no slots are available
  String _getNoSlotsDescription() {
    final now = DateTime.now();
    final isPastDate =
        selectedDate.isBefore(DateTime(now.year, now.month, now.day));
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    if (isPastDate) {
      return "Please select a future date to book an appointment.";
    } else if (isToday) {
      return "All slots for today have passed or are fully booked. Please try another date.";
    } else {
      return "The clinic hasn't set up their schedule for this date yet, or all slots are booked. Please try another date.";
    }
  }

  // Format price with improved peso symbol visibility
  String _formatPeso(String price) {
    final priceStr = price.trim();

    // Check if it's a range
    if (priceStr.contains('-') || priceStr.toLowerCase().contains('to')) {
      final parts =
          priceStr.split(RegExp(r'\s*[-–]\s*|\s+to\s+', caseSensitive: false));
      if (parts.length == 2) {
        final low =
            double.tryParse(parts[0].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final high =
            double.tryParse(parts[1].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        return CurrencyFormatter.formatPesoRange(low, high);
      }
    }

    return CurrencyFormatter.formatPeso(priceStr);
  }

  // Create a fade-only route for smooth navigation
  Route<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade =
            CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(opacity: fade, child: child);
      },
    );
  }

  Future<void> _fetchAvailableSlots() async {
    List<String> tempAvailableSlots = [];
    List<String> tempBookedSlots = [];

    try {
      print('DEBUG: ==================== FETCHING SLOTS ====================');
      print('DEBUG: Clinic ID: ${widget.clinicId}');
      print('DEBUG: Service ID: ${widget.serviceId}');
      print(
          'DEBUG: Selected Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}');
      print('DEBUG: Current Year: ${DateTime.now().year}');
      print('DEBUG: Selected Year: ${selectedDate.year}');
      print(
          'DEBUG: Philippines time now: ${DateTime.now().toUtc().add(Duration(hours: 8))}');

      // Convert selected date to Philippines timezone format for database query
      final philippinesDate =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final dateString = DateFormat('yyyy-MM-dd').format(philippinesDate);
      print('DEBUG: Formatted date for query: $dateString');

      // Fetch staff schedule
      print('DEBUG: About to query clinics_sched table...');

      // Test query - fetch ALL schedules first
      try {
        final testResponse =
            await supabase.from('clinics_sched').select('*').limit(5);
        print('DEBUG: Test query - ALL schedules: $testResponse');

        // Test query for specific date
        final dateTestResponse = await supabase
            .from('clinics_sched')
            .select('*')
            .eq('date', dateString);
        print(
            'DEBUG: Test query - Specific date ($dateString): $dateTestResponse');

        // Test query for specific clinic
        final clinicTestResponse = await supabase
            .from('clinics_sched')
            .select('*')
            .eq('clinic_id', widget.clinicId);
        print('DEBUG: Test query - Specific clinic: $clinicTestResponse');
      } catch (e) {
        print('DEBUG: Test query failed: $e');
      }

      final scheduleResponse = await supabase
          .from('clinics_sched')
          .select('date, start_time, end_time, schedule_pattern')
          .eq('clinic_id', widget.clinicId);

      print('DEBUG: Query completed. Raw response: $scheduleResponse');
      print('DEBUG: Response type: ${scheduleResponse.runtimeType}');
      print('DEBUG: Response length: ${scheduleResponse.length}');

      print(
          'DEBUG: Found ${scheduleResponse.length} schedule entries for clinic ${widget.clinicId}');
      print(
          'DEBUG: Looking for date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}');
      print(
          'DEBUG: Selected date components: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}');

      for (var schedule in scheduleResponse) {
        print(
            'DEBUG: Schedule entry: ${schedule['date']} ${schedule['start_time']}-${schedule['end_time']} pattern: ${schedule['schedule_pattern']}');
        final scheduleDate = DateTime.parse(schedule['date']);
        print(
            'DEBUG: Parsed schedule date: ${scheduleDate.year}-${scheduleDate.month.toString().padLeft(2, '0')}-${scheduleDate.day.toString().padLeft(2, '0')}');

        if (scheduleDate.year == selectedDate.year &&
            scheduleDate.month == selectedDate.month &&
            scheduleDate.day == selectedDate.day) {
          final int startTime = schedule['start_time'];
          final int endTime = schedule['end_time'];
          final String? schedulePattern = schedule['schedule_pattern'];

          // Determine time interval based on schedule pattern
          // Pinoy Hustler uses 30-minute intervals, all others use 1-hour intervals
          final int intervalMinutes =
              (schedulePattern == 'Pinoy Hustler') ? 30 : 60;

          // Generate time slots with the appropriate interval
          tempAvailableSlots.addAll(_generateTimeSlots(startTime, endTime,
              intervalMinutes: intervalMinutes));
          print(
              'DEBUG: ✅ MATCH! Added slots from ${startTime}:00 to ${endTime}:00 with ${intervalMinutes}min interval (pattern: $schedulePattern) for date ${schedule['date']}');
        } else {
          print(
              'DEBUG: ❌ NO MATCH - Schedule date ${schedule['date']} != Selected date ${DateFormat('yyyy-MM-dd').format(selectedDate)}');
        }
      }

      // Fetch booked slots (only pending or approved block the slot)
      // Cancelled and rejected bookings should NOT block slots
      final bookedResponse = await supabase
          .from('bookings')
          .select('date, start_time')
          .eq('clinic_id', widget.clinicId)
          .eq('service_id', widget.serviceId)
          .inFilter('status',
              ['pending', 'approved']); // Only these statuses block slots

      tempBookedSlots = bookedResponse
          .where((b) {
            final d = DateTime.parse(b['date']).toLocal();
            return d.year == selectedDate.year &&
                d.month == selectedDate.month &&
                d.day == selectedDate.day;
          })
          .map<String>((b) {
            // start_time might be stored as string in your DB
            final v = b['start_time'];
            if (v is String) return v;
            if (v is int) {
              // Convert hour int to time slot string (e.g., 10 -> "10:00")
              return '${v.toString().padLeft(2, '0')}:00';
            }
            return '';
          })
          .where((v) => v.isNotEmpty)
          .toList();

      // Remove booked slots from available slots
      var filteredAvailable = tempAvailableSlots
          .where((slot) => !tempBookedSlots.contains(slot))
          .toList();

      final now = DateTime.now();
      final isToday = selectedDate.year == now.year &&
          selectedDate.month == now.month &&
          selectedDate.day == now.day;

      if (isToday) {
        // Remove slots that have already passed (including current time slot)
        final currentMinutes = now.hour * 60 + now.minute;
        filteredAvailable.removeWhere((slot) {
          final slotMinutes = _timeSlotToMinutes(slot);
          // Hide slots that have passed or are currently happening
          return slotMinutes <= currentMinutes;
        });
      }

      // For past dates, show no slots at all
      final isPastDate =
          selectedDate.isBefore(DateTime(now.year, now.month, now.day));
      if (isPastDate) {
        filteredAvailable.clear();
      }

      // Sort slots chronologically
      filteredAvailable.sort(
          (a, b) => _timeSlotToMinutes(a).compareTo(_timeSlotToMinutes(b)));

      print('DEBUG: Final available slots: $filteredAvailable');
      print('DEBUG: Booked slots (pending/approved only): $tempBookedSlots');
      print('DEBUG: Is today: $isToday, Is past date: $isPastDate');

      setState(() {
        availableSlots = filteredAvailable;
        bookedSlots = tempBookedSlots;
        selectedSlot = null;
      });
    } catch (e) {
      print('DEBUG: Error fetching slots: $e');
      setState(() => errorMessage = 'Error fetching slots: $e');
    }
  }

  Future<void> _bookService() async {
    if (selectedSlot == null) {
      setState(() => errorMessage = "Please select a time.");
      return;
    }

    setState(() {
      isBooking = true;
      errorMessage = null;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        errorMessage = "You must be logged in to book a service.";
        isBooking = false;
      });
      return;
    }

    // Parse the selected time slot (e.g., "10:30" -> hour: 10, minute: 30)
    final timeParts = selectedSlot!.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final appointmentDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      hour,
      minute,
    );

    // Calculate end time (assuming 30-minute appointments)
    final endDateTime = appointmentDateTime.add(const Duration(minutes: 30));

    try {
      await supabase.from('bookings').insert({
        'patient_id': user.id,
        'clinic_id': widget.clinicId,
        'service_id': widget.serviceId,
        'date': appointmentDateTime.toIso8601String(),
        'start_time':
            selectedSlot!, // Store as time slot string (e.g., "10:30")
        'end_time':
            '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}',
        'status': 'pending',
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        _fadeRoute(PatientBookingSuccess()),
      );
    } catch (e) {
      setState(() => errorMessage = "Error booking service: $e");
    } finally {
      setState(() => isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Set Appointment",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Service Summary Card
            _CardSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue,
                      child: const Icon(Icons.medical_services,
                          color: Colors.white),
                    ),
                    title: Text(
                      widget.serviceName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_formatPeso(widget.servicePrice)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.serviceDetail,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Date Selection Card
            _CardSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                      icon: Icons.date_range, title: "Select a Date"),
                  const SizedBox(height: 8),
                  TableCalendar(
                    firstDay: DateTime.now(),
                    lastDay: DateTime.now().add(const Duration(days: 30)),
                    focusedDay: selectedDate,
                    calendarFormat: calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() => selectedDate = selectedDay);
                      _fetchAvailableSlots();
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                          color: Colors.blueAccent, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Time Selection Card
            _CardSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                      icon: Icons.access_time, title: "Select a Time"),
                  const SizedBox(height: 10),
                  if (availableSlots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.warningColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.schedule,
                              color: AppTheme.warningColor, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            _getNoSlotsMessage(),
                            style: GoogleFonts.poppins(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getNoSlotsDescription(),
                            style: GoogleFonts.poppins(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((slot) {
                        final isSelected = selectedSlot == slot;
                        return ChoiceChip(
                          label: Text(_formatTimeSlotToAmPm(
                              slot)), // Display time slot in AM-PM format
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => selectedSlot = slot);
                          },
                          selectedColor: AppTheme.primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: AppTheme.softBlue,
                        );
                      }).toList(),
                    ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMessage!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Confirm Card
            _CardSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isBooking || availableSlots.isEmpty
                          ? null
                          : _bookService,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isBooking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Confirm Appointment",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Reusable section card with padding and subtle shadow
class _CardSection extends StatelessWidget {
  final Widget child;
  const _CardSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
