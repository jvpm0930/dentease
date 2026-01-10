import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/utils/database_error_handler.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdmClinicReviews extends StatefulWidget {
  final String clinicId;
  const AdmClinicReviews({super.key, required this.clinicId});

  @override
  State<AdmClinicReviews> createState() => _AdmClinicReviewsState();
}

class _AdmClinicReviewsState extends State<AdmClinicReviews> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> reviews = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '📋 [AdminClinicReviews] Initializing for clinicId: ${widget.clinicId}');
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    debugPrint(
        '🔄 [AdminClinicReviews] Starting to fetch reviews for clinicId: ${widget.clinicId}');

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get current user info for debugging
      final currentUser = supabase.auth.currentUser;
      debugPrint('👤 [AdminClinicReviews] Current user ID: ${currentUser?.id}');

      debugPrint('📡 [AdminClinicReviews] Executing query for feedbacks...');

      // Use the database error handler with retry logic
      final response = await DatabaseErrorHandler.executeWithRetry(
        () => supabase
            .from('feedbacks')
            .select(
              'feedback_id, clinic_id, patient_id, rating, feedback, created_at',
            )
            .eq('clinic_id', widget.clinicId)
            .order('created_at', ascending: false),
        'AdminClinicReviews',
      );

      if (response == null) {
        throw Exception('Failed to fetch reviews after retries');
      }

      debugPrint('✅ [AdminClinicReviews] Query completed successfully');
      debugPrint('📊 [AdminClinicReviews] Raw response: $response');
      debugPrint(
          '📊 [AdminClinicReviews] Number of reviews found: ${response.length}');

      final reviewsList = List<Map<String, dynamic>>.from(response);

      // Step 2: Fetch patient names for these reviews
      Map<String, String> patientNames = {};
      final patientIds = reviewsList
          .map((r) => r['patient_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (patientIds.isNotEmpty) {
        debugPrint(
            '📡 [AdminClinicReviews] Fetching patient names for ${patientIds.length} patients...');
        try {
          final patientsResponse = await DatabaseErrorHandler.executeWithRetry(
            () => supabase
                .from('patients')
                .select('patient_id, firstname, lastname')
                .inFilter('patient_id', patientIds),
            'AdminClinicReviews-Patients',
          );

          if (patientsResponse != null) {
            for (var p in patientsResponse) {
              final name =
                  '${p['firstname'] ?? ''} ${p['lastname'] ?? ''}'.trim();
              patientNames[p['patient_id'].toString()] =
                  name.isNotEmpty ? name : 'Anonymous Patient';
            }
            debugPrint(
                '✅ [AdminClinicReviews] Fetched ${patientNames.length} patient names');
          }
        } catch (pe) {
          debugPrint(
              '⚠️ [AdminClinicReviews] Error fetching patient names: $pe');
        }
      }

      // Step 3: Combine data
      for (var review in reviewsList) {
        final pId = review['patient_id']?.toString();
        review['patient_display_name'] = patientNames[pId] ??
            (pId != null
                ? 'Patient #${pId.substring(0, 8)}...'
                : 'Unknown Patient');
      }

      if (mounted) {
        setState(() {
          reviews = reviewsList;
          isLoading = false;
        });
      }

      debugPrint(
          '🎯 [AdminClinicReviews] State updated with ${reviews.length} reviews and names');
    } catch (e, stackTrace) {
      DatabaseErrorHandler.logError('AdminClinicReviews', e, stackTrace);

      if (mounted) {
        setState(() {
          errorMessage = DatabaseErrorHandler.getReadableError(e);
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🏗️ [AdminClinicReviews] Building UI - isLoading: $isLoading, reviews count: ${reviews.length}, error: $errorMessage');

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const BackButton(color: Colors.black),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          title: const Text(
            'Clinic Reviews',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                debugPrint('🔄 [AdminClinicReviews] Manual refresh triggered');
                _fetchReviews();
              },
            ),
          ],
        ),
        body: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading reviews...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Error Loading Reviews',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchReviews,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Reviews Yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This clinic has no patient reviews yet.',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Reviews will appear here once patients submit their feedback.',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchReviews,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final patientName =
                                review['patient_display_name'] ??
                                    'Unknown Patient';

                            debugPrint(
                                '🎨 [AdminClinicReviews] Rendering review card $index: $patientName');

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                title: Text(
                                  patientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (review['rating'] != null)
                                      Row(
                                        children: [
                                          const Text(
                                            'Rating: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          ...List.generate(
                                            5,
                                            (i) => Icon(
                                              i <
                                                      (review['rating']
                                                              as int? ??
                                                          0)
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ),
                                          Text(' (${review['rating']})'),
                                        ],
                                      ),
                                    if (review['feedback'] != null &&
                                        review['feedback']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Comment: ${review['feedback']}'),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${DateFormat('MMM d, yyyy').format(DateTime.parse(review['created_at']))}',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
