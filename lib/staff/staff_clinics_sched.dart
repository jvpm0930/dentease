import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffClinicSchedPage extends StatefulWidget {
  final String staffId;
  final String clinicId;

  const StaffClinicSchedPage(
      {super.key, required this.staffId, required this.clinicId});

  @override
  _StaffClinicSchedPageState createState() => _StaffClinicSchedPageState();
}

class _StaffClinicSchedPageState extends State<StaffClinicSchedPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> schedules = [];
  DateTime selectedDate = DateTime.now();
  int startHour = 9;
  int endHour = 17;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    startHour = DateTime.now().hour; // Set startHour to the current hour
    _fetchSchedule();
  }


  /// 🔹 Fetch the existing schedule for the dentist
  Future<void> _fetchSchedule() async {
    final response = await supabase
        .from('clinics_sched')
        .select()
        .eq('staff_id', widget.staffId)
        .eq('clinic_id', widget.clinicId)
        .order('date', ascending: true);

    setState(() {
      schedules = List<Map<String, dynamic>>.from(response);
    });
  }

  /// Add a new schedule (Prevents Duplicates)
  Future<void> _addSchedule() async {
    setState(() => isLoading = true);

    // Convert date to just YYYY-MM-DD format
    String formattedDate = selectedDate.toIso8601String().split('T')[0];

    // Check if a schedule already exists for this date and time
    final existingSchedules = await supabase
        .from('clinics_sched')
        .select()
        .eq('staff_id', widget.staffId)
        .eq('clinic_id', widget.clinicId)
        .eq('date', formattedDate)
        .eq('start_time', startHour)
        .eq('end_time', endHour);

    if (existingSchedules.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule already exists!'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    // Proceed with inserting a new schedule
    final newSchedule = {
      'staff_id': widget.staffId,
      'clinic_id': widget.clinicId,
      'date': formattedDate,
      'start_time': startHour,
      'end_time': endHour,
    };

    final response =
        await supabase.from('clinics_sched').insert(newSchedule).select();

    if (response.isNotEmpty) {
      setState(() {
        schedules.add(response.first);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule added successfully!')),
      );
    }

    setState(() => isLoading = false);
  }


  /// 🔹 Delete a schedule
  Future<void> _deleteSchedule(String id) async {
    await supabase.from('clinics_sched').delete().eq('sched_id', id);

    setState(() {
      schedules.removeWhere((schedule) => schedule['sched_id'] == id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule deleted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Manage Schedule",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Date Picker
            ListTile(
              title: Text(
                  "Selected Date: ${selectedDate.toLocal()}".split(' ')[0],
                    style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
              ),
            ),

            // Start & End Hour Pickers side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Start Time",
                          style: TextStyle(color: Colors.white)),
                      DropdownButton<int>(
                        value: startHour,
                        isExpanded: true,
                        items: List.generate(24, (index) => index)
                            .map((hour) => DropdownMenuItem(
                                value: hour, child: Text("$hour:00")))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => startHour = value!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16), // Space between dropdowns
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("End Time",
                          style: TextStyle(color: Colors.white)),
                      DropdownButton<int>(
                        value: endHour,
                        isExpanded: true,
                        items: List.generate(24, (index) => index)
                            .map((hour) => DropdownMenuItem(
                                value: hour, child: Text("$hour:00")))
                            .toList(),
                        onChanged: (value) => setState(() => endHour = value!),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _addSchedule,
                    child: const Text("Save Schedule",
                        style: TextStyle(color: Colors.blue)),
                  ),

            const SizedBox(height: 20),

            // Display existing schedules
            Expanded(
              child: ListView.builder(
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text("Date: ${schedule['date'].split('T')[0]}",
                          style: const TextStyle(color: Colors.black)),
                      subtitle: Text(
                          "Time: ${schedule['start_time']}:00 - ${schedule['end_time']}:00",
                          style: const TextStyle(color: Colors.black)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSchedule(schedule['sched_id']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}
