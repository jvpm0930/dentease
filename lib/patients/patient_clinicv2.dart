import 'package:dentease/patients/patient_booking.dart';
import 'package:dentease/patients/patient_feedbackPage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientClinicInfoPage extends StatefulWidget {
  final String clinicId;

  const PatientClinicInfoPage({super.key, required this.clinicId});

  @override
  _PatientClinicInfoPageState createState() => _PatientClinicInfoPageState();
}

class _PatientClinicInfoPageState extends State<PatientClinicInfoPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? clinic;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> reviews = [];
  bool isLoading = true;
  String errorMessage = '';


  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  /// **🔹 Fetch clinic details and approved services with feedbacks**
  Future<void> _fetchClinicDetails() async {
    try {
      // Fetch clinic details
      final clinicResponse = await supabase
          .from('clinics')
          .select('clinic_name, info, address, profile_url')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      // Fetch only approved services for this clinic
      final servicesResponse = await supabase
          .from('services')
          .select('service_id, service_name, service_price')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'active'); 
      
      final response = await supabase
          .from('feedbacks')
          .select('rating, feedback, patient_id, patients(firstname, lastname, profile_url)')
          .eq('clinic_id', widget.clinicId)
          .order('created_at', ascending: false);

      setState(() {
        clinic = clinicResponse;
        services = List<Map<String, dynamic>>.from(servicesResponse);
        reviews = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching clinic details: $e';
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0.5,
          title: const Text('Clinic Info'),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(
                    child: Text(errorMessage,
                        style: const TextStyle(color: Colors.red)))
                : clinic == null
                    ? const Center(child: Text("Clinic not found"))
                    : DefaultTabController(
                        length: 2,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Clinic image
                              SizedBox(
                                width: double.infinity,
                                height: 300,
                                child: clinic!['profile_url'] != null &&
                                        clinic!['profile_url']
                                            .toString()
                                            .isNotEmpty
                                    ? Image.network(
                                        clinic!['profile_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Center(
                                                child: Icon(
                                                    Icons.image_not_supported)),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                            child: Icon(Icons.image,
                                                size: 60, color: Colors.white)),
                                      ),
                              ),

                              // Clinic Name & Address below image
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clinic!['clinic_name'] ??
                                          'Unknown Clinic',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            color: Colors.redAccent, size: 18),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            clinic!['address'] ?? 'No address',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // TabBar
                              Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey, width: 0.5)),
                                ),
                                child: const TabBar(
                                  tabs: [
                                    Tab(text: 'Services'),
                                    Tab(text: 'Reviews'),
                                  ],
                                  labelColor: Colors.black,
                                  indicatorColor: Colors.blueAccent,
                                ),
                              ),

                              SizedBox(
                                height: 400, // Fixed height for tab content
                                child: TabBarView(
                                  children: [
                                    // SERVICES TAB
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: services.isEmpty
                                          ? const Text(
                                              "No approved services available.",
                                              style:
                                                  TextStyle(color: Colors.grey))
                                          : Column(
                                              children: services.map((service) {
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                      bottom: 12),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.grey
                                                            .withOpacity(0.1),
                                                        blurRadius: 4,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: const Icon(
                                                        Icons.medical_services,
                                                        color: Colors.blueAccent),
                                                    title: Text(service[
                                                        'service_name']),
                                                    subtitle: Text(
                                                        "Price: ${service['service_price']} php"),
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              PatientBookingPage(
                                                            serviceId: service[
                                                                'service_id'],
                                                            serviceName: service[
                                                                'service_name'],
                                                            clinicId:
                                                                widget.clinicId,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                    ),

                                    // Reviews Tab
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // Add Review button
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PatientFeedbackpage(
                                                          clinicId:
                                                              widget.clinicId),
                                                ),
                                              ).then((_) =>
                                                  _fetchClinicDetails()); // refresh on return
                                            },
                                            icon: const Icon(Icons.feedback),
                                            label: const Text("Add Review"),
                                          ),
                                          const SizedBox(height: 16),

                                          // Feedback List
                                          reviews.isEmpty
                                              ? const Text(
                                                  "No feedbacks available.",
                                                  style: TextStyle(
                                                      color: Colors.grey),
                                                )
                                              : Column(
                                                  children:reviews.map((review) {
                                                    return Container(
                                                      margin: const EdgeInsets.only(bottom: 12),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: Colors.grey.shade300),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.grey.withOpacity(0.1),
                                                            blurRadius: 4,
                                                            offset:const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        leading: CircleAvatar(
                                                          radius: 24,
                                                          backgroundColor:
                                                              Colors.grey[200],
                                                          backgroundImage: review['patients'] != null &&
                                                                  review['patients']['profile_url'] != null &&
                                                                  review['patients']['profile_url'].toString().isNotEmpty
                                                              ? NetworkImage(review['patients']['profile_url'])
                                                              : null,
                                                          child: review['patients'] != null &&
                                                                  (review['patients']['profile_url'] == null || 
                                                                  review['patients']['profile_url'].toString().isEmpty)
                                                              ? const Icon(Icons.person, color: Colors.grey)
                                                              : null,
                                                        ),
                                                        title: Text(
                                                          review['patients'] != null
                                                              ? '${review['patients']['firstname']} ${review['patients']['lastname']}'
                                                              : 'Anonymous',
                                                          style: const TextStyle(fontWeight:FontWeight.bold),
                                                        ),
                                                        subtitle: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children:List.generate(
                                                                5,
                                                                (index) => Icon(
                                                                  index <
                                                                          int.tryParse(review['rating']
                                                                              .toString())!
                                                                      ? Icons.star
                                                                      : Icons.star_border,
                                                                  color: Colors.amber,
                                                                  size: 18,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(review['feedback'] ?? ''),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                        ],
                                      ),
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
}
