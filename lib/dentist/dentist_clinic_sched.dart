import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _DentistClinicSchedPageState extends State<DentistClinicSchedPage>
    with SingleTickerProviderStateMixin {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  late TabController _tabController;

  static const kPrimaryBlue = Color(0xFF1134A6); // Primary Blue
  static const kBackground = Color(0xFFF8FAFC); // Clean medical background

  // Quick Patterns
  final List<Map<String, dynamic>> patterns = [
    {
      'title': 'Standard',
      'desc': 'Mon-Fri (9am-5pm)',
      'days': [1, 2, 3, 4, 5],
      'start': 9,
      'end': 17
    },
    {
      'title': 'Pinoy Hustler',
      'desc': 'Mon-Sat (9am-5pm)',
      'days': [1, 2, 3, 4, 5, 6],
      'start': 9,
      'end': 17
    },
    {
      'title': 'Mall Clinic',
      'desc': 'Mon-Sun (10am-8pm)',
      'days': [1, 2, 3, 4, 5, 6, 7],
      'start': 10,
      'end': 20
    },
    {
      'title': 'Half-Day Sat',
      'desc': 'M-F (9-5), Sat (8-12)',
      'days': [1, 2, 3, 4, 5],
      'start': 9,
      'end': 17,
      'sat_half': true
    },
  ];

  DateTime selectedDate = DateTime.now();
  int startHour = 9;
  int endHour = 17;
  bool isFetching = true;
  bool isGenerating = false;
  List<Map<String, dynamic>> schedules = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSchedule();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedule() async {
    setState(() => isFetching = true);
    try {
      final response = await supabase
          .from('clinics_sched')
          .select()
          .eq('clinic_id', widget.clinicId)
          .gte(
              'date',
              DateTime.now()
                  .toIso8601String()
                  .split('T')[0]) // Only future/today
          .order('date', ascending: true)
          .order('start_time', ascending: true);

      setState(() {
        schedules = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Error loading schedules: $e");
    } finally {
      if (mounted) setState(() => isFetching = false);
    }
  }

  // Generate Pattern Logic
  Future<void> _applyPattern(Map<String, dynamic> pattern) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Apply ${pattern['title']}?"),
        content: const Text(
            "This will generate entries for the next 30 days. Existing schedules will not be overwritten, but duplicates will be skipped."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue, foregroundColor: Colors.white),
            child: const Text("Generate"),
          )
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isGenerating = true);

    try {
      final List<int> days = pattern['days'];
      final int start = pattern['start'];
      final int end = pattern['end'];
      final bool satHalf = pattern['sat_half'] == true;

      final now = DateTime.now();
      final List<Map<String, dynamic>> toInsert = [];

      for (int i = 0; i < 30; i++) {
        final d = now.add(Duration(days: i));

        // Handle Half-day Saturday special case
        if (satHalf && d.weekday == 6) {
          toInsert.add({
            'clinic_id': widget.clinicId,
            'date': DateFormat('yyyy-MM-dd').format(d),
            'start_time': 8,
            'end_time': 12,
            'schedule_pattern': pattern['title'], // Store the pattern type
          });
          continue;
        }

        if (days.contains(d.weekday)) {
          toInsert.add({
            'clinic_id': widget.clinicId,
            'date': DateFormat('yyyy-MM-dd').format(d),
            'start_time': start,
            'end_time': end,
            'schedule_pattern': pattern['title'], // Store the pattern type
          });
        }
      }

      // Check conflicts (naively by just trying to insert)
      // Or check one by one. For bulk insert, supabase usually allows upsert or ignore duplicates.
      // Since we don't know constraints, we'll loop check to be safe (or just upsert if we had sched_id).
      // Since sched_id is auto-inc, we can't easily upsert efficiently without unique constraint on (clinic_id, date, start_time).
      // We will check for existence of date.

      int addedCount = 0;
      for (var entry in toInsert) {
        final date = entry['date'];
        final exists = schedules.any((s) => s['date'] == date);
        if (!exists) {
          await supabase.from('clinics_sched').insert(entry);
          addedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Generated $addedCount new schedule entries.")));
      }

      _fetchSchedule();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: Text(
            "Schedule Management",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: kPrimaryBlue, // Professional blue header
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: "My Schedule"),
              Tab(text: "Apply Pattern"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: List + Manual Add
            _buildListTab(),
            // Tab 2: Pattern Wizard
            _buildPatternTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab() {
    return RefreshIndicator(
      onRefresh: _fetchSchedule,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Add Button
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text("Add Single Date"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kPrimaryBlue,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          if (isFetching)
            const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          else if (schedules.isEmpty)
            Center(
                child: Text(
                    "No schedules set. Go to 'Apply Pattern' tab to quick start.",
                    style: TextStyle(color: Colors.grey.shade600)))
          else
            ...schedules.map((s) => _ScheduleCard(
                s: s, onDelete: () => _deleteSchedule(s['sched_id'])))
        ],
      ),
    );
  }

  Widget _buildPatternTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text("Choose a Work Pattern",
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text("Automatically generate schedule for the next 30 days.",
              style: GoogleFonts.roboto(color: const Color(0xFF64748B))),
          const SizedBox(height: 20),
          if (isGenerating)
            const CircularProgressIndicator(color: kPrimaryBlue),
          ...patterns.map((p) => Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(p['title'],
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                  subtitle: Text(p['desc'],
                      style: GoogleFonts.roboto(color: Colors.grey.shade600)),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => _applyPattern(p),
                ),
              ))
        ],
      ),
    );
  }

  Future<void> _showAddDialog() async {
    // Reuse existing logic or simple dialog
    // For brevity, just calling the date picker logic inline
    // ... (Implementation akin to previous manual add, but simplified)
    DateTime date = DateTime.now();
    int start = 9;
    int end = 17;

    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (context, setSB) => AlertDialog(
                title: const Text("Add Schedule"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                        title: Text(DateFormat('MMM d, yyyy').format(date)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)));
                          if (d != null) setSB(() => date = d);
                        }),
                    Row(children: [
                      const Text("Start: "),
                      DropdownButton<int>(
                          value: start,
                          items: List.generate(
                              24,
                              (i) => DropdownMenuItem(
                                  value: i, child: Text("$i:00"))).toList(),
                          onChanged: (v) => setSB(() => start = v!)),
                    ]),
                    Row(children: [
                      const Text("End:   "),
                      DropdownButton<int>(
                          value: end,
                          items: List.generate(
                              24,
                              (i) => DropdownMenuItem(
                                  value: i, child: Text("$i:00"))).toList(),
                          onChanged: (v) => setSB(() => end = v!)),
                    ]),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel")),
                  ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _manualAdd(date, start, end);
                      },
                      child: const Text("Save"))
                ],
              ),
            ));
  }

  Future<void> _manualAdd(DateTime date, int start, int end) async {
    try {
      await supabase.from('clinics_sched').insert({
        'clinic_id': widget.clinicId,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'start_time': start,
        'end_time': end,
        'schedule_pattern': 'Custom', // Default to Custom (1-hour intervals)
      });
      _fetchSchedule();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _deleteSchedule(dynamic id) async {
    await supabase.from('clinics_sched').delete().eq('sched_id', id);
    _fetchSchedule();
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> s;
  final VoidCallback onDelete;
  const _ScheduleCard({required this.s, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(s['date']);
    final start = s['start_time'];
    final end = s['end_time'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEEE, MMM d').format(date),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              Text("${_fmtTime(start)} - ${_fmtTime(end)}",
                  style: GoogleFonts.roboto(color: Colors.grey)),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete),
        ],
      ),
    );
  }

  String _fmtTime(int h) {
    final t = TimeOfDay(hour: h, minute: 0);
    return "${t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}";
  }
}
