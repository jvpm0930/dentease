import 'package:dentease/dentist/dentist_add_service.dart';
import 'package:dentease/dentist/dentist_service_details.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:dentease/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistServListPage extends StatefulWidget {
  final String clinicId;

  const DentistServListPage({super.key, required this.clinicId});

  @override
  State<DentistServListPage> createState() => _DentistServListPageState();
}

class _DentistServListPageState extends State<DentistServListPage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  List<Map<String, dynamic>> services = [];
  String? dentistId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistId();
    _fetchServices();
  }

  Future<void> _fetchDentistId() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) {
        setState(() => isLoading = false);
        return;
      }

      final response = await supabase
          .from('dentists')
          .select('dentist_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (response != null && response['dentist_id'] != null) {
        setState(() {
          dentistId = response['dentist_id'].toString();
        });
      }
    } catch (e) {
      // ignore but keep UI responsive
    }
  }

  Future<void> _fetchServices() async {
    try {
      final response = await supabase
          .from('services')
          .select(
              'service_id, service_name, service_price, max_price, status, pricing_type')
          .eq('clinic_id', widget.clinicId)
          .neq('status', 'deleted'); // Filter out soft-deleted services

      setState(() {
        services = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching services: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteService(String id, String serviceName) async {
    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Service?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$serviceName"?',
              style: GoogleFonts.roboto(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.warningColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This service will be hidden from patients but existing bookings will not be affected.',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppTheme.textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.errorButtonStyle,
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Use soft delete - set status to 'deleted' instead of actually deleting
      // This prevents foreign key constraint violations
      await supabase.from('services').update({
        'status': 'deleted',
      }).eq('service_id', id);

      setState(() {
        services.removeWhere((service) => service['service_id'] == id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Service deleted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting service: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _refresh() async {
    await _fetchServices();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            "Clinic Services",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              top: 10,
              bottom: 100,
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue))
                  : RefreshIndicator(
                      color: AppTheme.primaryBlue,
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        children: [
                          // Add Button
                          _buildAddButton(),
                          const SizedBox(height: 24),

                          // List
                          if (services.isEmpty)
                            _buildEmptyState()
                          else
                            ...services.map((s) => _ServiceCard(
                                  s: s,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DentistServiceDetailsPage(
                                          serviceId: s['service_id'].toString(),
                                        ),
                                      ),
                                    );
                                    _fetchServices();
                                  },
                                  onDelete: () => _deleteService(
                                    s['service_id'],
                                    s['service_name'] ?? 'Unknown Service',
                                  ),
                                )),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DentistAddService(
                  clinicId: widget.clinicId,
                ),
              ),
            );
            _fetchServices();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add,
                      color: AppTheme.primaryBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  "Add New Service",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.medical_services_outlined,
              size: 64, color: AppTheme.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            "No Services Found",
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap 'Add New Service' above to get started.",
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> s;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.s,
    required this.onTap,
    required this.onDelete,
  });

  String _getPricingTypeLabel(dynamic pricingType) {
    switch (pricingType?.toString()) {
      case 'per_tooth':
        return 'per tooth';
      case 'per_session':
        return 'per session';
      case 'per_unit':
        return 'per unit';
      case 'per_area':
        return 'per area';
      case 'whole':
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (s['status'] ?? '').toString();
    final isActive = status.toLowerCase() == 'active';
    final name = (s['service_name'] ?? 'N/A').toString();
    final price = (s['service_price'] ?? '0').toString();
    final maxPrice = (s['max_price'])?.toString(); // Get max price

    String priceDisplay;
    if (maxPrice != null && maxPrice.isNotEmpty && maxPrice != 'null') {
      priceDisplay = CurrencyFormatter.formatPesoRange(price, maxPrice);
    } else {
      priceDisplay = CurrencyFormatter.formatPeso(price);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      color: AppTheme.primaryBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            priceDisplay,
                            style: GoogleFonts.roboto(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                              fontSize: 15,
                            ),
                          ),
                          if (_getPricingTypeLabel(s['pricing_type'])
                              .isNotEmpty) ...[
                            Text(
                              ' ${_getPricingTypeLabel(s['pricing_type'])}',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: AppTheme.textGrey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.successColor.withValues(alpha: 0.1)
                                  : AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? "Active" : "Inactive",
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.textGrey.withValues(alpha: 0.6)),
                  onPressed: onDelete,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
