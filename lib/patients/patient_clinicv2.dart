import 'package:dentease/logic/safe_navigator.dart';
import 'package:dentease/patients/patient_booking.dart';
import 'package:dentease/patients/patient_feedbackPage.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:dentease/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientClinicInfoPage extends StatefulWidget {
  final String clinicId;
  const PatientClinicInfoPage({super.key, required this.clinicId});

  @override
  State<PatientClinicInfoPage> createState() => _PatientClinicInfoPageState();
}

class _PatientClinicInfoPageState extends State<PatientClinicInfoPage>
    with SingleTickerProviderStateMixin {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  Map<String, dynamic>? clinic;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> reviews = [];
  bool isLoading = true;
  String errorMessage = '';
  bool hasBooking = false;
  String? patientId;

  late TabController _tabController;

  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kDarkBlue = AppTheme.primaryBlue;
  static const kTextPrimary = Color(0xFF1C1C1E);
  static const kTextSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    patientId = supabase.auth.currentUser?.id;
    _fetchClinicDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatPrice(dynamic price, dynamic maxPrice) {
    if (price == null) return CurrencyFormatter.formatPeso(0);

    // Check for max price (range)
    if (maxPrice != null && maxPrice.toString().toLowerCase() != 'null') {
      final maxStr = maxPrice.toString().trim();
      final numMax =
          double.tryParse(maxStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final numPrice =
          double.tryParse(price.toString().replaceAll(RegExp(r'[^\d.]'), '')) ??
              0;

      if (numMax > numPrice) {
        return CurrencyFormatter.formatPesoRange(numPrice, numMax);
      }
    }

    return CurrencyFormatter.formatPeso(price);
  }

  String _getPricingTypeLabel(String? pricingType) {
    switch (pricingType) {
      case 'per_tooth':
        return 'Per Tooth';
      case 'per_session':
        return 'Per Session';
      case 'per_unit':
        return 'Per Unit';
      case 'per_area':
        return 'Per Area';
      case 'whole':
        return 'Whole Treatment';
      default:
        return '';
    }
  }

  Future<void> _fetchClinicDetails() async {
    try {
      final clinicResponse = await supabase
          .from('clinics')
          .select('clinic_name, info, address, office_url, profile_url')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      final servicesResponse = await supabase
          .from('services')
          .select(
              'service_id, service_name, service_price, service_detail, pricing_type, max_price')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'active');

      final feedbackResponse = await supabase
          .from('feedbacks')
          .select(
              'rating, feedback, patient_id, patients(firstname, lastname, profile_url)')
          .eq('clinic_id', widget.clinicId)
          .order('created_at', ascending: false);

      bool bookingExists = false;
      if (patientId != null) {
        // Check for approved OR completed bookings to allow reviews after treatment
        final bookingCheck = await supabase
            .from('bookings')
            .select('booking_id')
            .eq('clinic_id', widget.clinicId)
            .eq('patient_id', patientId!)
            .or('status.eq.approved,status.eq.completed')
            .limit(1);
        bookingExists = bookingCheck.isNotEmpty;
      }

      setState(() {
        clinic = clinicResponse;
        services = List<Map<String, dynamic>>.from(servicesResponse);
        reviews = List<Map<String, dynamic>>.from(feedbackResponse);
        hasBooking = bookingExists;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching clinic details: $e';
        isLoading = false;
      });
    }
  }

  double _calculateAverageRating() {
    if (reviews.isEmpty) return 0;
    double total = 0;
    for (var review in reviews) {
      total += double.tryParse(review['rating'].toString()) ?? 0;
    }
    return total / reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.red)))
              : clinic == null
                  ? const Center(child: Text("Clinic not found"))
                  : CustomScrollView(
                      slivers: [
                        // Hero Image with AppBar
                        _buildHeroSection(),

                        // Clinic Info Card
                        SliverToBoxAdapter(child: _buildClinicInfoCard()),

                        // Tab Bar
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarDelegate(
                            TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(text: 'Services'),
                                Tab(text: 'Reviews'),
                              ],
                              labelColor: kDarkBlue,
                              unselectedLabelColor: kTextSecondary,
                              indicatorColor: kDarkBlue,
                              indicatorWeight: 3,
                              labelStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        // Tab Content
                        SliverFillRemaining(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildServicesTab(),
                              _buildReviewsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildHeroSection() {
    final imageUrl = clinic!['office_url'] ?? clinic!['profile_url'];
    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: kDarkBlue,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (hasImage)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: kDarkBlue,
                  child: const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: kDarkBlue,
                  child: const Icon(Icons.local_hospital,
                      size: 60, color: Colors.white54),
                ),
              )
            else
              Container(
                color: kDarkBlue,
                child: const Icon(Icons.local_hospital,
                    size: 60, color: Colors.white54),
              ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Clinic Name & Address
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic!['clinic_name'] ?? 'Unknown Clinic',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          clinic!['address'] ?? 'No address',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildClinicInfoCard() {
    final avgRating = _calculateAverageRating();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Section (Moved Up)
          if ((clinic?['info'] ?? '').toString().isNotEmpty) ...[
            Text(
              'About',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              clinic!['info'] ?? '',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: kTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
          ],

          // Rating Row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      avgRating > 0 ? avgRating.toStringAsFixed(1) : 'New',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${reviews.length} reviews)',
                style: GoogleFonts.roboto(
                  color: kTextSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${services.length} Services',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    if (services.isEmpty) {
      return Center(
        child: Text(
          'No services available',
          style: GoogleFonts.roboto(color: kTextSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(service);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final formattedPrice =
        _formatPrice(service['service_price'], service['max_price']);
    final pricingTypeLabel = _getPricingTypeLabel(service['pricing_type']);

    return GestureDetector(
      onTap: () {
        SafeNavigator.push(
          context,
          PatientBookingPage(
            serviceId: service['service_id'],
            serviceName: service['service_name'],
            servicePrice: formattedPrice, // Pass the formatted range string
            serviceDetail: service['service_detail'] ?? '',
            clinicId: widget.clinicId,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: kDarkBlue,
                size: 24,
              ),
            ),

            const SizedBox(width: 14),

            // Service Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['service_name'] ?? 'Unknown Service',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  if ((service['service_detail'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      service['service_detail'],
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: kTextSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Pricing Type Chip (Moved here for better visibility)
                  if (pricingTypeLabel.isNotEmpty &&
                      pricingTypeLabel != 'Whole Treatment') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        pricingTypeLabel,
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Price Badge & Action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formattedPrice,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Book Now',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add Review Button
        if (hasBooking)
          GestureDetector(
            onTap: () {
              SafeNavigator.push(
                context,
                PatientFeedbackpage(clinicId: widget.clinicId),
              )?.then((_) => _fetchClinicDetails());
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimaryBlue, kDarkBlue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rate_review_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Write a Review',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Reviews List
        if (reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.reviews_outlined,
                      size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews yet',
                    style: GoogleFonts.roboto(color: kTextSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...reviews.map((review) => _buildReviewCard(review)),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final patient = review['patients'];
    final rating = int.tryParse(review['rating'].toString()) ?? 0;
    final profileUrl = patient?['profile_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: kPrimaryBlue.withValues(alpha: 0.1),
                backgroundImage:
                    profileUrl != null && profileUrl.toString().isNotEmpty
                        ? NetworkImage(profileUrl)
                        : null,
                child: profileUrl == null || profileUrl.toString().isEmpty
                    ? Icon(Icons.person, color: kPrimaryBlue, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),

              // Name & Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient != null
                          ? '${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''}'
                              .trim()
                          : 'Anonymous',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((review['feedback'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review['feedback'],
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: kTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _TabBarDelegate(this._tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
