import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistClinicSchedPage extends StatefulWidget {
  final String clinicId;

  const DentistClinicSchedPage({
    super.key,
    required this.clinicId,
  });

  @override
  _DentistClinicSchedPageState createState() => _DentistClinicSchedPageState();
}

class _DentistClinicSchedPageState extends State<DentistClinicSchedPage> {
  final supabase = Supabase.instance.client;
  final Color kPrimary = const Color(0xFF103D7E);

  final DateFormat _dateFmt = DateFormat('MMM d, y');

  List<Map<String, dynamic>> schedules = [];
  DateTime selectedDate = DateTime.now();
  int startHour = 9;
  int endHour = 10;

  bool isFetching = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startHour = now.hour;
    endHour = (startHour + 1).clamp(1, 23);
    _fetchSchedule();
  }

  String _hourLabel(int hour) {
    final t = TimeOfDay(hour: hour, minute: 0);
    return t.format(context);
  }

  String _formatDateStr(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    final base = s.contains('T') ? s.split('T').first : s;
    final dt = DateTime.tryParse(base);
    return dt == null ? base : _dateFmt.format(dt);
  }

  Future<void> _fetchSchedule() async {
    setState(() => isFetching = true);
    try {
      final response = await supabase
          .from('clinics_sched')
          .select()
          .eq('clinic_id', widget.clinicId)
          .order('date', ascending: true)
          .order('start_time', ascending: true);

      setState(() {
        schedules = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading schedules: $e')),
      );
    } finally {
      if (mounted) setState(() => isFetching = false);
    }
  }

  Future<void> _addSchedule() async {
    if (endHour <= startHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be later than start time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    try {
      final existing = await supabase
          .from('clinics_sched')
          .select()
          .eq('clinic_id', widget.clinicId)
          .eq('date', formattedDate)
          .eq('start_time', startHour)
          .eq('end_time', endHour);

      if (existing.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule already exists!'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isSaving = false);
        return;
      }

      final newSchedule = {
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
          schedules.sort((a, b) {
            final da = DateTime.parse(a['date'].toString());
            final db = DateTime.parse(b['date'].toString());
            final cmp = da.compareTo(db);
            if (cmp != 0) return cmp;
            return (a['start_time'] as int).compareTo(b['start_time'] as int);
          });
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule added successfully!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding schedule: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _confirmDelete(dynamic schedId) async {
    final idStr = schedId.toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) _deleteSchedule(idStr);
  }

  Future<void> _deleteSchedule(String id) async {
    try {
      await supabase.from('clinics_sched').delete().eq('sched_id', id);
      setState(() {
        schedules.removeWhere((s) => s['sched_id'].toString() == id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule deleted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting schedule: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startOptions = List.generate(24, (i) => i);
    final endOptions = List.generate(24 - (startHour + 1), (i) => startHour + 1 + i);

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Manage Schedule",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _fetchSchedule,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Create Schedule Card
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: Icons.calendar_month_rounded,
                        title: "Create Schedule",
                        color: kPrimary,
                      ),
                      const SizedBox(height: 12),

                      // Date picker row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Selected date: ${_dateFmt.format(selectedDate)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 60)),
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.edit_calendar_rounded),
                            label: const Text("Pick Date"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimary,
                              side: BorderSide(color: kPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Time pickers
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: startHour,
                              decoration: _inputDecoration(
                                label: "Start Time",
                                icon: Icons.schedule,
                              ),
                              items: startOptions
                                  .map((h) => DropdownMenuItem(
                                        value: h,
                                        child: Text(_hourLabel(h)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  startHour = v;
                                  if (endHour <= startHour) {
                                    endHour = (startHour + 1).clamp(1, 23);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: endHour,
                              decoration: _inputDecoration(
                                label: "End Time",
                                icon: Icons.schedule_outlined,
                              ),
                              items: endOptions
                                  .map((h) => DropdownMenuItem(
                                        value: h,
                                        child: Text(_hourLabel(h)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => endHour = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _addSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Save Schedule",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Existing schedules
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: Icons.event_note_rounded,
                        title: "Existing Schedules",
                        color: kPrimary,
                      ),
                      const SizedBox(height: 12),
                      if (isFetching)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (schedules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "No schedules found. Add one above.",
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      else
                        ListView.separated(
                          itemCount: schedules.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = schedules[index];
                            final dateStr = _formatDateStr(s['date']);
                            final st = s['start_time'] as int? ?? 0;
                            final et = s['end_time'] as int? ?? 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: kPrimary.withOpacity(0.1),
                                  foregroundColor: kPrimary,
                                  child: const Icon(Icons.schedule),
                                ),
                                title: Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  "${_hourLabel(st)} - ${_hourLabel(et)}",
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _confirmDelete(s['sched_id']),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null ? Icon(icon, color: kPrimary) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
                    BoxShadow(
            color: Color(0x14000000),
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
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.color = const Color(0xFF103D7E),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
