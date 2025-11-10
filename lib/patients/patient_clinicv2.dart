import 'package:dentease/patients/patient_booking.dart';
import 'package:dentease/patients/patient_feedbackPage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientClinicInfoPage extends StatefulWidget {
  final String clinicId;
  const PatientClinicInfoPage({super.key, required this.clinicId});

  @override
  State<PatientClinicInfoPage> createState() => _PatientClinicInfoPageState();
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

  Future<void> _fetchClinicDetails() async {
    try {
      final clinicResponse = await supabase
          .from('clinics')
          .select('clinic_name, info, address, office_url')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      final servicesResponse = await supabase
          .from('services')
          .select('service_id, service_name, service_price, service_detail')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'active');

      final feedbackResponse = await supabase
          .from('feedbacks')
          .select(
              'rating, feedback, patient_id, patients(firstname, lastname, profile_url)')
          .eq('clinic_id', widget.clinicId)
          .order('created_at', ascending: false);

      setState(() {
        clinic = clinicResponse;
        services = List<Map<String, dynamic>>.from(servicesResponse);
        reviews = List<Map<String, dynamic>>.from(feedbackResponse);
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
          title: const Text('Clinic Info', style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0.5,
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
                        child: NestedScrollView(
                          headerSliverBuilder: (context, innerBoxIsScrolled) =>
                              [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Clinic image
                                  SizedBox(
                                    width: double.infinity,
                                    height: 300,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Background image or placeholder
                                        if (clinic!['office_url'] != null &&
                                            clinic!['office_url']
                                                .toString()
                                                .isNotEmpty)
                                          Image.network(
                                            clinic!['office_url'],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                    child: Icon(Icons
                                                        .image_not_supported)),
                                              );
                                            },
                                          )
                                        else
                                          Container(
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: Icon(Icons.image,
                                                  size: 60,
                                                  color: Colors.white),
                                            ),
                                          ),

                                        // Gradient overlay (for readable text)
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black26,
                                                  Colors.black54,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Bottom-left overlay: clinic name and address
                                        Positioned(
                                          left: 16,
                                          right: 16,
                                          bottom: 16,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                clinic!['clinic_name'] ??
                                                    'Unknown Clinic',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.location_on,
                                                      color: Colors.red,
                                                      size: 18),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      clinic!['address'] ??
                                                          'No address',
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Clinic details
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.info,
                                                color: Colors.indigo, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                (clinic?['info'] ?? '')
                                                        .toString()
                                                        .isNotEmpty
                                                    ? clinic!['info']
                                                    : 'No information available',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                    ) ,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        const Divider(thickness: 1.5),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TabBarDelegate(
                                const TabBar(
                                  tabs: [
                                    Tab(text: 'Services'),
                                    Tab(text: 'Reviews'),
                                  ],
                                  labelColor: Colors.black,
                                  indicatorColor: Color(0xFF103D7E),
                                ),
                              ),
                            ),
                          ],
                          body: TabBarView(
                            children: [
                              // SERVICES TAB
                              ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: services.length,
                                itemBuilder: (context, index) {
                                  final service = services[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: const Icon(
                                          Icons.medical_services,
                                          color: Color(0xFF103D7E)),
                                      title: Text(service['service_name'], style: TextStyle(
                                        fontWeight: FontWeight.bold
                                      ),),
                                      subtitle: Text(
                                          "Price: ${service['service_price']}"),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PatientBookingPage(
                                              serviceId: service['service_id'],
                                              serviceName:
                                                  service['service_name'],
                                              servicePrice:
                                                  service['service_price'],
                                              serviceDetail:
                                                  service['service_detail'],
                                              clinicId: widget.clinicId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),

                              // REVIEWS TAB
                              ListView(
                                padding: const EdgeInsets.all(25),
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PatientFeedbackpage(
                                                  clinicId: widget.clinicId),
                                        ),
                                      ).then((_) => _fetchClinicDetails());
                                    },
                                    icon: const Icon(Icons.feedback, color: Color(0xFF103D7E)),
                                    label: const Text("Add Review", style: TextStyle(
                                      color: Color(0xFF103D7E),
                                      fontWeight: FontWeight.bold,
                                    ),),
                                  ),
                                  const SizedBox(height: 16),
                                  if (reviews.isEmpty)
                                    const Text(
                                      "No feedbacks available.",
                                      style: TextStyle(color: Colors.grey),
                                    )
                                  else
                                    ...reviews.map((review) {
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.grey[200],
                                            backgroundImage: review[
                                                            'patients'] !=
                                                        null &&
                                                    review['patients']
                                                            ['profile_url'] !=
                                                        null &&
                                                    review['patients']
                                                            ['profile_url']
                                                        .toString()
                                                        .isNotEmpty
                                                ? NetworkImage(
                                                    review['patients']
                                                        ['profile_url'])
                                                : null,
                                            child: review['patients'] != null &&
                                                    (review['patients'][
                                                                'profile_url'] ==
                                                            null ||
                                                        review['patients']
                                                                ['profile_url']
                                                            .toString()
                                                            .isEmpty)
                                                ? const Icon(Icons.person,
                                                    color: Colors.grey)
                                                : null,
                                          ),
                                          title: Text(
                                            review['patients'] != null
                                                ? '${review['patients']['firstname']} ${review['patients']['lastname']}'
                                                : 'Anonymous',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (index) => Icon(
                                                    index <
                                                            int.tryParse(review[
                                                                    'rating']
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
                                    }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
      ),
    );
  }
}

// Helper for pinned tab bar
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _TabBarDelegate(this._tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: const Color.fromARGB(98, 162, 192, 206), child: _tabBar);
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
