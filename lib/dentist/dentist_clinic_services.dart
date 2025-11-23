import 'package:dentease/dentist/dentist_add_service.dart';
import 'package:dentease/dentist/dentist_service_details.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/widgets/background_cont.dart';

class DentistServListPage extends StatefulWidget {
  final String clinicId;

  const DentistServListPage({super.key, required this.clinicId});

  @override
  _DentistServListPageState createState() => _DentistServListPageState();
}

class _DentistServListPageState extends State<DentistServListPage> {
  final supabase = Supabase.instance.client;
  final Color kPrimary = const Color(0xFF103D7E);

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
          .select('service_id, service_name, service_price, status')
          .eq('clinic_id', widget.clinicId);

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

  Future<void> _deleteService(String id) async {
    try {
      // Check if linked to any bills
      final billResponse =
          await supabase.from('bills').select('bill_id').eq('service_id', id);

      if (billResponse.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot delete: This service is linked to existing bills.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await supabase.from('services').delete().eq('service_id', id);

      setState(() {
        services.removeWhere((service) => service['service_id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refresh() async {
    await _fetchServices();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Clinic Services",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              top: 30,
              bottom: 100,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: ElevatedButton.icon(
                                onPressed: () async {
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: kPrimary,
                                  elevation: 3,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: kPrimary, width: 1),
                                  ),
                                ),
                                icon: Icon(Icons.add, color: kPrimary),
                                label: Text(
                                  "Add New Services",
                                  style: TextStyle(
                                    color: kPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (services.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: _EmptyState(primary: kPrimary),
                              )
                            else
                              ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: services.length,
                                itemBuilder: (context, index) {
                                  final s = services[index];
                                  final status = (s['status'] ?? '').toString();
                                  final statusColor =
                                      status.toLowerCase() == 'inactive'
                                          ? Colors.red
                                          : kPrimary;

                                  return _ServiceCard(
                                    primary: kPrimary,
                                    name:
                                        (s['service_name'] ?? 'N/A').toString(),
                                    price: (s['service_price'] ?? 'N/A')
                                        .toString(),
                                    status: status,
                                    statusColor: statusColor,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              DentistServiceDetailsPage(
                                            serviceId:
                                                s['service_id'].toString(),
                                          ),
                                        ),
                                      );
                                      _fetchServices();
                                    },
                                    onDelete: () =>
                                        _deleteService(s['service_id']),
                                  );
                                },
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
            ),
            if (dentistId != null)
              DentistFooter(
                clinicId: widget.clinicId,
                dentistId: dentistId!,
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Color primary;
  final String name;
  final String price;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.primary,
    required this.name,
    required this.price,
    required this.status,
    required this.statusColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: primary.withOpacity(0.1),
                  foregroundColor: primary,
                  child: const Icon(Icons.medical_services),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Chips row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              icon: Icons.change_circle_outlined,
                              label: price,
                              bg: Colors.grey.shade100,
                              fg: Colors.black87,
                              border: Colors.grey.shade300,
                            ),
                            _InfoChip(
                              icon: Icons.flag_rounded,
                              label: status,
                              bg: statusColor.withOpacity(0.12),
                              fg: statusColor,
                              border: statusColor.withOpacity(0.2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                    ),
                    const SizedBox(height: 6),
                    const Icon(Icons.chevron_right, color: Colors.black45),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color primary;
  const _EmptyState({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "No services found for this clinic. Tap “Add New Services” to create one.",
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
