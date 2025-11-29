import 'package:dentease/patients/patient_bookingSuccess.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

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
  final supabase = Supabase.instance.client;

  DateTime selectedDate = DateTime.now();
  CalendarFormat calendarFormat = CalendarFormat.month;
  bool isBooking = false;
  String? errorMessage;

  List<int> availableHours = [];
  List<int> bookedHours = [];
  int? selectedHour; // Replaces TimeOfDay for chip-based selection

  @override
  void initState() {
    super.initState();
    _fetchAvailableSlots();
  }

  // Format an hour int (0-23) to "h:00 AM/PM"
  String _formatHour(int hour) {
    final time = TimeOfDay(hour: hour, minute: 0);
    return time.format(context);
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
    List<int> tempAvailableHours = [];
    List<int> tempBookedHours = [];

    try {
      // Fetch staff schedule
      final scheduleResponse = await supabase
          .from('clinics_sched')
          .select('date, start_time, end_time')
          .eq('clinic_id', widget.clinicId);

      for (var schedule in scheduleResponse) {
        final scheduleDate = DateTime.parse(schedule['date']);
        if (scheduleDate.year == selectedDate.year &&
            scheduleDate.month == selectedDate.month &&
            scheduleDate.day == selectedDate.day) {
          final int startTime = schedule['start_time'];
          final int endTime = schedule['end_time'];
          for (int h = startTime; h <= endTime; h++) {
            tempAvailableHours.add(h);
          }
        }
      }

      // Fetch booked slots
      final bookedResponse = await supabase
          .from('bookings')
          .select('date, start_time')
          .eq('clinic_id', widget.clinicId)
          .eq('service_id', widget.serviceId);

      tempBookedHours = bookedResponse
          .where((b) {
            final d = DateTime.parse(b['date']);
            return d.year == selectedDate.year &&
                d.month == selectedDate.month &&
                d.day == selectedDate.day;
          })
          .map<int>((b) {
            // start_time might be stored as string or int in your DB
            final v = b['start_time'];
            if (v is int) return v;
            if (v is String) return int.tryParse(v) ?? -1;
            return -1;
          })
          .where((v) => v >= 0)
          .toList();

      var filteredAvailable = tempAvailableHours
          .where((h) => !tempBookedHours.contains(h))
          .toList();
          
      final now = DateTime.now();
      if (selectedDate.year == now.year &&
          selectedDate.month == now.month &&
          selectedDate.day == now.day) {
        filteredAvailable.removeWhere((h) => h <= now.hour);
      }

      filteredAvailable.sort();


      setState(() {
        availableHours = filteredAvailable;
        bookedHours = tempBookedHours;
        selectedHour = null;
      });

    } catch (e) {
      setState(() => errorMessage = 'Error fetching slots: $e');
    }
  }

  Future<void> _bookService() async {
    if (selectedHour == null) {
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

    final appointmentDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedHour!, // hour selected via chip
      0,
    );

    final startTime = selectedHour!;
    final endTime = startTime + 1;

    try {
      await supabase.from('bookings').insert({
        'patient_id': user.id,
        'clinic_id': widget.clinicId,
        'service_id': widget.serviceId,
        'date': appointmentDateTime.toIso8601String(),
        'start_time': startTime.toString(), // keep as string for compatibility
        'end_time': endTime.toString(),
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
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Set Appointment"), titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold, 
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
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
                        backgroundColor: const Color(0xFF103D7E),
                        child: const Icon(Icons.medical_services,
                            color: Colors.white),
                      ),
                      title: Text(
                        widget.serviceName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Price: ${widget.servicePrice}"),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.serviceDetail,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
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
                      selectedDayPredicate: (day) =>
                          isSameDay(selectedDate, day),
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
                    if (availableHours.isEmpty)
                      const Text(
                        "No available slots for this date.",
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableHours.map((hour) {
                          final isSelected = selectedHour == hour;
                          return ChoiceChip(
                            label: Text(_formatHour(hour)),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => selectedHour = hour);
                            },
                            selectedColor: const Color(0xFF103D7E),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor: Colors.grey[200],
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
                        onPressed: isBooking || availableHours.isEmpty
                            ? null
                            : _bookService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF103D7E),
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
        color: Colors.white.withOpacity(0.98),
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
        Icon(icon, color: const Color(0xFF103D7E)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
