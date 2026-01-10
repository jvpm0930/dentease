import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dentease/utils/currency_formatter.dart';

/// Financial Dashboard Analytics for Clinics - New Theme UI
class ClinicAnalytics extends StatefulWidget {
  final String clinicId;
  const ClinicAnalytics({super.key, required this.clinicId});

  @override
  State<ClinicAnalytics> createState() => _ClinicAnalyticsState();
}

class _ClinicAnalyticsState extends State<ClinicAnalytics> {
  final supabase = Supabase.instance.client;

  // Modern Medical Theme Colors
  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kBackground = Color(0xFFF5F7FA);
  static const kTextDark = Color(0xFF1E293B);
  static const kTextGrey = Color(0xFF64748B);

  bool isLoading = true;
  RealtimeChannel? _subscription;

  // Analytics Data
  double totalRevenue = 0.0;
  double monthlyRevenue = 0.0;
  double dailyRevenue = 0.0;
  int totalPatients = 0;
  int servicesOffered = 0;
  int monthlyBookings = 0;
  int completedBookings = 0;
  String mostCommonGender = 'N/A';
  double averagePatientAge = 0.0;

  List<Map<String, dynamic>> popularServices = [];
  List<FlSpot> patientsPerDay = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _subscription = supabase
        .channel('analytics_${widget.clinicId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clinic_id',
            value: widget.clinicId,
          ),
          callback: (payload) => _fetchAnalyticsData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bills',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clinic_id',
            value: widget.clinicId,
          ),
          callback: (payload) => _fetchAnalyticsData(),
        )
        .subscribe();
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      // --- 1. Fetch ALL Bills (for Revenue) ---
      // Removed 'created_at' as it does not exist in the bills table
      final billsResponse = await supabase
          .from('bills')
          .select('total_amount, booking_id')
          .eq('clinic_id', widget.clinicId);

      // --- 2. Fetch ALL Valid Bookings (for Dates, Patients, Services) ---
      final bookingsResponse = await supabase
          .from('bookings')
          .select('booking_id, date, patient_id, service_id, status')
          .eq('clinic_id', widget.clinicId)
          .neq('status', 'rejected')
          .neq('status', 'cancelled');

      // Create a map of BookingID -> Date for easy lookup
      final Map<String, DateTime> bookingDateMap = {};

      final List<Map<String, dynamic>> allBookings =
          List<Map<String, dynamic>>.from(bookingsResponse);
      final List<Map<String, dynamic>> monthlyBookingsList = [];

      for (var b in allBookings) {
        final bId = b['booking_id'].toString();
        final dateStr = b['date']?.toString();
        if (dateStr != null) {
          final d = DateTime.tryParse(dateStr);
          if (d != null) {
            bookingDateMap[bId] = d;

            // Filter for monthly stats
            if (d.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                d.isBefore(endOfMonth.add(const Duration(days: 1)))) {
              monthlyBookingsList.add(b);
            }
          }
        }
      }

      // --- 3. Calculate Revenue ---
      totalRevenue = 0.0;
      monthlyRevenue = 0.0;
      dailyRevenue = 0.0;

      for (var bill in billsResponse) {
        // ROBUST PARSING: Handle both Number and String types for total_amount
        double amount = 0.0;
        if (bill['total_amount'] != null) {
          if (bill['total_amount'] is num) {
            amount = (bill['total_amount'] as num).toDouble();
          } else if (bill['total_amount'] is String) {
            amount = double.tryParse(bill['total_amount'].toString()) ?? 0.0;
          }
        }

        final bId = bill['booking_id'].toString();

        // Add to Total
        totalRevenue += amount;

        // Determine Date: Rely solely on Booking Date
        final DateTime? billDate = bookingDateMap[bId];

        if (billDate != null) {
          // Monthly Revenue
          if (billDate.year == now.year && billDate.month == now.month) {
            monthlyRevenue += amount;
          }
          // Daily Revenue
          if (billDate.year == now.year &&
              billDate.month == now.month &&
              billDate.day == now.day) {
            dailyRevenue += amount;
          }
        }
      }

      // --- 4. Overview Stats (All Time) ---
      // Services Count
      final servicesResp = await supabase
          .from('services')
          .select('service_id')
          .eq('clinic_id', widget.clinicId)
          .neq('status', 'deleted');
      servicesOffered = servicesResp.length;

      // Monthly Bookings Count
      monthlyBookings = monthlyBookingsList.length;

      // Calculate Completed Bookings Count (for matching Dashboard "Total Completed")
      completedBookings =
          allBookings.where((b) => b['status'] == 'completed').length;

      // Total Unique Patients (All Time)
      final Set<String> uniquePatientIds = {};
      for (var b in allBookings) {
        if (b['patient_id'] != null) {
          uniquePatientIds.add(b['patient_id'].toString());
        }
      }
      totalPatients = uniquePatientIds.length;

      // --- 5. Demographics (All Time Patients) ---
      if (uniquePatientIds.isNotEmpty) {
        // Only fetch gender, dob, and age
        final patientsResp = await supabase
            .from('patients')
            .select('gender, date_of_birth, age')
            .inFilter('patient_id', uniquePatientIds.toList());

        int maleCount = 0;
        int femaleCount = 0;
        double totalAge = 0;
        int ageCount = 0;

        for (var p in patientsResp) {
          // Gender
          final g = p['gender']?.toString().toLowerCase().trim();
          if (g == 'male' || g == 'm') {
            maleCount++;
          } else if (g == 'female' || g == 'f') {
            femaleCount++;
          }

          // Age Calculation - ROBUST TYPE CHECKING
          int? patientAge;

          // Try explicit 'age' column first
          if (p['age'] != null) {
            if (p['age'] is num) {
              patientAge = (p['age'] as num).toInt();
            } else {
              patientAge = int.tryParse(p['age'].toString());
            }
          }

          // Fallback to calculation from DOB if 'age' is missing
          if (patientAge == null) {
            final dob = p['date_of_birth'];
            if (dob != null) {
              final birthDate = DateTime.tryParse(dob.toString());
              if (birthDate != null) {
                final calcAge = now.year - birthDate.year;
                if (calcAge > 0 && calcAge < 120) {
                  patientAge = calcAge;
                }
              }
            }
          }

          if (patientAge != null) {
            totalAge += patientAge;
            ageCount++;
          }
        }

        // Determine Common Gender
        if (maleCount > femaleCount) {
          mostCommonGender = 'Male';
        } else if (femaleCount > maleCount) {
          mostCommonGender = 'Female';
        } else if (maleCount > 0) {
          mostCommonGender = 'Equal';
        } else {
          mostCommonGender = 'N/A';
        }

        // Average Age
        if (ageCount > 0) {
          averagePatientAge = totalAge / ageCount;
        } else {
          averagePatientAge = 0.0;
        }
      }

      // --- 6. Patients Chart (This Month Only) ---
      final Map<int, int> dailyMap = {};
      for (var b in monthlyBookingsList) {
        final dStr = b['date']?.toString();
        if (dStr != null) {
          final d = DateTime.tryParse(dStr);
          if (d != null) {
            dailyMap[d.day] = (dailyMap[d.day] ?? 0) + 1;
          }
        }
      }

      patientsPerDay = dailyMap.entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));

      // --- 7. Popular Services (All Time) ---
      final Map<String, int> serviceCounts = {};
      for (var b in allBookings) {
        final sId = b['service_id']?.toString();
        if (sId != null) {
          serviceCounts[sId] = (serviceCounts[sId] ?? 0) + 1;
        }
      }

      popularServices = [];
      final sortedServices = serviceCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var entry in sortedServices.take(5)) {
        final sData = await supabase
            .from('services')
            .select('service_name')
            .eq('service_id', entry.key)
            .maybeSingle();

        if (sData != null) {
          popularServices.add({
            'name': sData['service_name'],
            'count': entry.value,
            'percentage': (allBookings.isNotEmpty)
                ? (entry.value / allBookings.length * 100).round()
                : 0,
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : RefreshIndicator(
              onRefresh: _fetchAnalyticsData,
              color: kPrimaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Revenue Section
                    _buildSectionTitle('Revenue'),
                    const SizedBox(height: 12),
                    _buildRevenueCards(),
                    const SizedBox(height: 24),

                    // Overview Stats
                    _buildSectionTitle('Overview'),
                    const SizedBox(height: 12),
                    _buildOverviewStats(),
                    const SizedBox(height: 24),

                    // Demographics
                    _buildSectionTitle('Patient Demographics'),
                    const SizedBox(height: 12),
                    _buildDemographicsRow(),
                    const SizedBox(height: 24),

                    // Patients Chart
                    if (patientsPerDay.isNotEmpty) ...[
                      _buildSectionTitle('Patients This Month'),
                      const SizedBox(height: 12),
                      _buildPatientsChart(),
                      const SizedBox(height: 24),
                    ],

                    // Popular Services
                    if (popularServices.isNotEmpty) ...[
                      _buildSectionTitle('Popular Services'),
                      const SizedBox(height: 12),
                      _buildPopularServices(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: kTextDark,
      ),
    );
  }

  Widget _buildRevenueCards() {
    return Column(
      children: [
        // Total Revenue - Featured Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Revenue',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatPesoWithText(totalRevenue),
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Monthly & Daily Revenue Row
        Row(
          children: [
            Expanded(
              child: _buildRevenueStatCard(
                title: 'Monthly Revenue',
                value: CurrencyFormatter.formatPesoWithText(monthlyRevenue),
                icon: Icons.calendar_month_rounded,
                color: kPrimaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRevenueStatCard(
                title: "Today's Revenue",
                value: CurrencyFormatter.formatPesoWithText(dailyRevenue),
                icon: Icons.today_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: kTextGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Patients',
            value: '$totalPatients',
            icon: Icons.people_alt_rounded,
            color: kPrimaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Services',
            value: '$servicesOffered',
            icon: Icons.medical_services_rounded,
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Completed',
            value: '$completedBookings',
            icon: Icons.check_circle_rounded,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: kTextGrey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDemographicCard(
            icon: Icons.wc_rounded,
            iconColor: Colors.pink,
            value: mostCommonGender,
            label: 'Common Gender',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDemographicCard(
            icon: Icons.cake_outlined,
            iconColor: Colors.deepOrange,
            value: averagePatientAge > 0
                ? '${averagePatientAge.toStringAsFixed(1)} yrs'
                : 'N/A',
            label: 'Avg. Patient Age',
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: kTextGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: patientsPerDay,
              isCurved: true,
              color: kPrimaryBlue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    kPrimaryBlue.withValues(alpha: 0.2),
                    kPrimaryBlue.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularServices() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: popularServices.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value;
          final colors = [
            Colors.green,
            kPrimaryBlue,
            Colors.orange,
            Colors.purple,
            Colors.pink
          ];
          final color = colors[index % colors.length];

          return Padding(
            padding: EdgeInsets.only(
                bottom: index < popularServices.length - 1 ? 16 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        service['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                    ),
                    Text(
                      '${service['count']} bookings',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: kTextGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: service['percentage'] / 100,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
