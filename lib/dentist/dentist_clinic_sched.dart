import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistClinicSchedPage extends StatefulWidget {
  final String dentistId;
  final String clinicId;

  const DentistClinicSchedPage(
      {super.key, required this.dentistId, required this.clinicId});

  @override
  _DentistClinicSchedPageState createState() => _DentistClinicSchedPageState();
}

class _DentistClinicSchedPageState extends State<DentistClinicSchedPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> schedules = [];
  DateTime selectedDate = DateTime.now();
  int startHour = 9;
  int endHour = 17;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    startHour = DateTime.now().hour;
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    final response = await supabase
        .from('clinics_sched')
        .select()
        .eq('dentist_id', widget.dentistId)
        .eq('clinic_id', widget.clinicId)
        .order('date', ascending: true);

    setState(() {
      schedules = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _addSchedule() async {
    setState(() => isLoading = true);

    String formattedDate = selectedDate.toIso8601String().split('T')[0];

    final existingSchedules = await supabase
        .from('clinics_sched')
        .select()
        .eq('dentist_id', widget.dentistId)
        .eq('clinic_id', widget.clinicId)
        .eq('date', formattedDate)
        .eq('start_time', startHour)
        .eq('end_time', endHour);

    if (existingSchedules.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule already exists!',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    final newSchedule = {
      'dentist_id': widget.dentistId,
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
        const SnackBar(
            content: Text('Schedule added successfully!')),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> _deleteSchedule(String id) async {
    await supabase.from('clinics_sched').delete().eq('sched_id', id);

    setState(() {
      schedules.removeWhere((schedule) => schedule['sched_id'] == id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Schedule deleted successfully!')),
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

                      setState(() => selectedDate = picked ?? selectedDate);
                                        }
                ),
              ),
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
                          dropdownColor: Colors.white,
                          items: List.generate(24, (index) => index)
                              .map((hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text("$hour:00")))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => startHour = value!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("End Time",
                            style: TextStyle(color: Colors.white)),
                        DropdownButton<int>(
                          value: endHour,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          items: List.generate(24, (index) => index)
                              .map((hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text("$hour:00")))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => endHour = value!),
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
                          onPressed: () =>
                              _deleteSchedule(schedule['sched_id']),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
