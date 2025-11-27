import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdmClinicReviews extends StatelessWidget {
  final String clinicId;
  const AdmClinicReviews({super.key, required this.clinicId});

  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('feedbacks')
        .select(
          'feedback_id, clinic_id, patient_id, rating, feedback, created_at, patients ( firstname, lastname )',
        )
        .eq('clinic_id', clinicId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          title: const Text('Clinic Reviews', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold ),),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchReviews(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No reviews found.'));
            }
            final reviews = snapshot.data!;
            return ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                      'Name: ${review['patients']['firstname']} ${review['patients']['lastname']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (review['rating'] != null)
                          Text('Rating: ${review['rating']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (review['feedback'] != null &&
                            review['feedback'].toString().isNotEmpty)
                          Text('Comment: ${review['feedback']}'),
                        Text(
                          'Date: ${DateFormat('MMM d, yyyy').format(DateTime.parse(review['created_at']))}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
