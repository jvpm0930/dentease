import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistServiceDetailsPage extends StatefulWidget {
  final String serviceId;

  const DentistServiceDetailsPage({super.key, required this.serviceId});

  @override
  _DentistServiceDetailsPageState createState() =>
      _DentistServiceDetailsPageState();
}

class _DentistServiceDetailsPageState extends State<DentistServiceDetailsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  static const Color kPrimary = Color(0xFF103D7E);

  // Controllers for nicer UX and formatting
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _detailsController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String errorMessage = '';
  String serviceStatus = 'active';

  @override
  void initState() {
    super.initState();
    _fetchServiceDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _fetchServiceDetails() async {
    try {
      final response = await supabase
          .from('services')
          .select('service_name, service_price, status, service_detail')
          .eq('service_id', widget.serviceId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _nameController.text = (response['service_name'] ?? '').toString();
          _priceController.text = (response['service_price'] ?? '').toString();
          _detailsController.text =
              (response['service_detail'] ?? '').toString();
          serviceStatus = (response['status'] ?? 'active').toString();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Service not found.";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching service details: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _updateService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('services').update({
        'service_name': _nameController.text.trim(),
        'service_price': _priceController.text.trim(),
        'service_detail': _detailsController.text.trim(),
        'status': serviceStatus,
      }).eq('service_id', widget.serviceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error updating service: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Service Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage.isNotEmpty)
              Center(
                child: Text(errorMessage,
                    style: const TextStyle(color: Colors.red)),
              )
            else
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Service',
                        ),
                        const SizedBox(height: 12),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            label: "Service Name",
                            icon: Icons.medical_services_outlined,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Enter service name"
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Price
                        TextFormField(
                          controller: _priceController,
                          decoration: _inputDecoration(
                            label: "Service Price",// fallback handled by text
                            prefixText: '₱ ',
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Enter service price"
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Details
                        TextFormField(
                          controller: _detailsController,
                          decoration: _inputDecoration(
                            label: "Service Details",
                            icon: Icons.description_outlined,
                          ).copyWith(alignLabelWithHint: true),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 3,
                          maxLines: null,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Enter service details"
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Status
                        DropdownButtonFormField<String>(
                          value: serviceStatus,
                          decoration: _inputDecoration(
                              label: "Status", icon: Icons.flag),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => serviceStatus = v ?? 'active'),
                        ),

                        const SizedBox(height: 20),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        Navigator.pop(context, false);
                                      },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(
                                      color: kPrimary, width: 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  foregroundColor: kPrimary,
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSaving ? null : _updateService,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Save Changes",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Saving overlay
            if (isSaving)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null ? Icon(icon, color: kPrimary) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF103D7E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
