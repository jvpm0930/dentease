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
  TimeOfDay? selectedTime;
  CalendarFormat calendarFormat = CalendarFormat.month;
  bool isBooking = false;
  String? errorMessage;

  List<int> availableHours = []; // Available hours from staff schedule
  List<int> bookedHours = []; // Booked slots

  @override
  void initState() {
    super.initState();
    _fetchAvailableSlots();
  }

  /// Fetch available staff schedule and booked slots
  Future<void> _fetchAvailableSlots() async {
    List<int> tempAvailableHours = [];
    List<int> tempBookedHours = [];

    // Fetch staff schedule from `clinic_sched`
    final scheduleResponse = await supabase
        .from('clinics_sched')
        .select('date, start_time, end_time, staff_id')
        .eq('clinic_id', widget.clinicId);

    for (var schedule in scheduleResponse) {
      DateTime scheduleDate = DateTime.parse(schedule['date']);
      if (scheduleDate.year == selectedDate.year &&
          scheduleDate.month == selectedDate.month &&
          scheduleDate.day == selectedDate.day) {
        int startTime = schedule['start_time'];
        int endTime = schedule['end_time'];
        for (int i = startTime; i <= endTime; i++) {
          tempAvailableHours.add(i);
        }
      }
    }

    // Fetch booked slots from `bookings`
    final bookedResponse = await supabase
        .from('bookings')
        .select('date, start_time')
        .eq('clinic_id', widget.clinicId)
        .eq('service_id', widget.serviceId);

    tempBookedHours = bookedResponse
        .where((booking) =>
            DateTime.parse(booking['date']).year == selectedDate.year &&
            DateTime.parse(booking['date']).month == selectedDate.month &&
            DateTime.parse(booking['date']).day == selectedDate.day)
        .map<int>((booking) => booking['start_time'])
        .toList();

    setState(() {
      availableHours = tempAvailableHours;
      bookedHours = tempBookedHours;

      if (availableHours.isNotEmpty) {
        // Auto-pick first available slot if nothing selected yet
        selectedTime ??= TimeOfDay(hour: availableHours.first, minute: 0);
      } else {
        selectedTime = null; // No slots available
      }
    });
  }

  Future<void> _bookService() async {
    if (selectedTime == null) {
      setState(() {
        errorMessage = "Please select a time.";
      });
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

    final DateTime appointmentDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    int startTime = selectedTime!.hour;
    int endTime = startTime + 1;

    try {
      await supabase.from('bookings').insert({
        'patient_id': user.id,
        'clinic_id': widget.clinicId,
        'service_id': widget.serviceId,
        'date': appointmentDateTime.toIso8601String(),
        'start_time': startTime.toString(),
        'end_time': endTime.toString(),
        'status': 'pending',
      });

      // Navigate to a success page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PatientBookingSuccess(),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = "Error booking service: $e";
      });
    } finally {
      setState(() {
        isBooking = false;
      });
    }
  }

  /// Show available time slots dialog
  Future<void> _selectTime(BuildContext context) async {
    int? pickedHour = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select an Available Time"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableHours.length,
              itemBuilder: (BuildContext context, int index) {
                final int hour = availableHours[index];
                bool isBooked = bookedHours.contains(hour);

                return ListTile(
                  title: Text(
                    TimeOfDay(hour: hour, minute: 0).format(context),
                    style:
                        TextStyle(color: isBooked ? Colors.grey : Colors.black),
                  ),
                  enabled: !isBooked,
                  onTap: isBooked
                      ? null
                      : () {
                          Navigator.pop(context, hour);
                        },
                );
              },
            ),
          ),
        );
      },
    );

    setState(() {
      selectedTime =
          TimeOfDay(hour: pickedHour ?? selectedTime!.hour, minute: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Book ${widget.serviceName}"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Service: ${widget.serviceName}",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Price: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(
                        text: widget.servicePrice.isNotEmpty
                            ? widget.servicePrice
                            : 'No price available',
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Details:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5), // spacing
                    Text(
                      widget.serviceDetail.isNotEmpty
                          ? widget.serviceDetail
                          : 'No details available',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.blueGrey),
                const SizedBox(height: 20),
                Text("Select a Date:",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 30)),
                  focusedDay: selectedDate,
                  calendarFormat: calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(selectedDate, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      selectedDate = selectedDay;
                    });
                    _fetchAvailableSlots();
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                        color: Colors.blueAccent, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const SizedBox(height: 20),
                Text("Select a Time:",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: availableHours.isEmpty
                      ? null
                      : () => _selectTime(context),
                  child: Text(
                    availableHours.isEmpty
                        ? "No Slots Available"
                        : "Selected Time: ${selectedTime!.format(context)}",
                  ),
                ),
                const SizedBox(height: 5),
                const Divider(thickness: 1.5, color: Colors.blueGrey),
                const SizedBox(height: 5),
                if (errorMessage != null)
                  Text(errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _bookService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo[900],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 5,
                    ),
                    child: const Text(
                      "Confirm Booking",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
