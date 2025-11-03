import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicAnalytics extends StatefulWidget {
  final String clinicId; // Clinic identifier
  const ClinicAnalytics({super.key, required this.clinicId});

  @override
  State<ClinicAnalytics> createState() => _ClinicAnalyticsState();
}

class _ClinicAnalyticsState extends State<ClinicAnalytics> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  // Dashboard values
  String topService = "Loading...";
  String mostCommonGender = "Loading...";
  double averageAge = 0.0;
  int servicesOffered = 0;
  int bookedCount = 0;
  int totalPatients = 0;
  double totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchClinicStats();
  }

  Future<void> _fetchClinicStats() async {
    try {
      setState(() => _isLoading = true);

      final clinicId = widget.clinicId;

      //  Get total number of services offered
      final servicesResponse = await supabase
          .from('services')
          .select('service_id')
          .eq('clinic_id', clinicId);
      servicesOffered = servicesResponse.length;

      //  Get total number of booked services
      final bookingsResponse = await supabase
          .from('bookings')
          .select('service_id, patient_id')
          .eq('clinic_id', clinicId);
      bookedCount = bookingsResponse.length;

      //  Get unique patients (for gender & age stats)
      final patientIds = <String>{};
      for (var booking in bookingsResponse) {
        if (booking['patient_id'] != null) {
          patientIds.add(booking['patient_id']);
        }
      }
      totalPatients = patientIds.length;

      //  Get total revenue
      final billsResponse = await supabase
          .from('bills')
          .select('total_amount')
          .eq('clinic_id', clinicId);

      totalRevenue = 0.0;
      for (var bill in billsResponse) {
        final amount = bill['total_amount'];
        if (amount != null) {
          if (amount is num) {
            totalRevenue += amount.toDouble();
          } else if (amount is String) {
            totalRevenue += double.tryParse(amount) ?? 0.0;
          }
        }
      }

      //  Get top booked service
      final Map<String, int> serviceCount = {};
      for (var booking in bookingsResponse) {
        final serviceId = booking['service_id'];
        if (serviceId != null) {
          serviceCount[serviceId] = (serviceCount[serviceId] ?? 0) + 1;
        }
      }

      if (serviceCount.isNotEmpty) {
        final topServiceId = serviceCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

        final serviceData = await supabase
            .from('services')
            .select('service_name')
            .eq('service_id', topServiceId)
            .maybeSingle();

        topService = serviceData?['service_name'] ?? "N/A";
      } else {
        topService = "No bookings yet";
      }

      // Fetch gender and age from `patients`
      String mostGender = "N/A";
      double avgAge = 0.0;

      if (patientIds.isNotEmpty) {
        final patientsResponse = await supabase
            .from('patients')
            .select('gender, age')
            .inFilter('patient_id', patientIds.toList());

        // Count genders
        final Map<String, int> genderCount = {};
        double ageSum = 0;
        int validAgeCount = 0;

        for (var patient in patientsResponse) {
          final gender = patient['gender'] ?? 'Not Specified';
          genderCount[gender] = (genderCount[gender] ?? 0) + 1;

          final age = patient['age'];
          if (age != null) {
            if (age is num) {
              ageSum += age.toDouble();
              validAgeCount++;
            } else if (age is String) {
              final parsed = double.tryParse(age);
              if (parsed != null) {
                ageSum += parsed;
                validAgeCount++;
              }
            }
          }
        }

        // Get most gender
        if (genderCount.isNotEmpty) {
          mostGender = genderCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
        }

        // Compute average age
        if (validAgeCount > 0) {
          avgAge = ageSum / validAgeCount;
        }

        mostCommonGender = mostGender;
        averageAge = avgAge;
      } else {
        mostCommonGender = "No patients yet";
        averageAge = 0.0;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() {
        _isLoading = false;
        topService = "Error loading data";
      });
    }
  }


  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      color: color ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigo[100],
              radius: 25,
              child: Icon(icon, color: Colors.indigo[800], size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Clinic Dashboard",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchClinicStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatCard(
                        title: "Top Booked Service",
                        value: topService,
                        icon: Icons.star,
                      ),
                      _buildStatCard(
                        title: "Total Number of Services Offered",
                        value: "$servicesOffered",
                        icon: Icons.medical_services_outlined,
                      ),
                      _buildStatCard(
                        title: "Total Number of Booked Services",
                        value: "$bookedCount",
                        icon: Icons.calendar_month,
                      ),
                      _buildStatCard(
                        title: "Total Number of Patients",
                        value: "$totalPatients",
                        icon: Icons.people,
                      ),
                      _buildStatCard(
                        title: "Most Common Gender",
                        value: mostCommonGender,
                        icon: Icons.wc,
                      ),
                      _buildStatCard(
                        title: "Average Patient Age",
                        value: "${averageAge.toStringAsFixed(1)} yrs",
                        icon: Icons.cake,
                      ),
                      _buildStatCard(
                        title: "Total Revenue Generated",
                        value: "₱${totalRevenue.toStringAsFixed(2)}",
                        icon: Icons.attach_money,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
