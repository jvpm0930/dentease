import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const Color kPrimaryBlue = Color(0xFF0D2A7A);
  static const Color kTextDark = Color(0xFF1E293B);

  // Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxPriceController =
      TextEditingController(); // Add max price controller
  final _detailsController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool isRangePricing = false; // Toggle state
  String errorMessage = '';
  String serviceStatus = 'active';
  String pricingType = 'whole';

  // Pricing Type Options
  static const List<Map<String, String>> pricingTypes = [
    {'value': 'whole', 'label': 'Whole Treatment'},
    {'value': 'per_tooth', 'label': 'Per Tooth'},
    {'value': 'per_session', 'label': 'Per Session'},
    {'value': 'per_unit', 'label': 'Per Unit'},
    {'value': 'per_area', 'label': 'Per Area'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchServiceDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _maxPriceController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _fetchServiceDetails() async {
    try {
      final response = await supabase
          .from('services')
          .select(
              'service_name, service_price, max_price, status, service_detail, pricing_type')
          .eq('service_id', widget.serviceId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _nameController.text = (response['service_name'] ?? '').toString();
          _priceController.text = (response['service_price'] ?? '').toString();

          // Handle Max Price
          final maxPrice = response['max_price'];
          if (maxPrice != null &&
              maxPrice.toString().isNotEmpty &&
              maxPrice != 'null') {
            _maxPriceController.text = maxPrice.toString();
            isRangePricing = true;
          }

          _detailsController.text =
              (response['service_detail'] ?? '').toString();
          serviceStatus = (response['status'] ?? 'active').toString();
          pricingType = (response['pricing_type'] ?? 'whole').toString();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Service not found.";
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error fetching service details: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      // Parse price as number
      final priceValue = double.tryParse(_priceController.text.trim());
      if (priceValue == null || priceValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
        setState(() => isSaving = false);
        return;
      }

      // Parse max price
      double? maxPriceValue;
      if (isRangePricing) {
        maxPriceValue = double.tryParse(_maxPriceController.text.trim());
        if (maxPriceValue == null || maxPriceValue <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid max price')),
          );
          setState(() => isSaving = false);
          return;
        }
        if (maxPriceValue <= priceValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Max price must be greater than Min price')),
          );
          setState(() => isSaving = false);
          return;
        }
      }

      await supabase.from('services').update({
        'service_name': _nameController.text.trim(),
        'service_price': priceValue,
        'max_price': isRangePricing ? maxPriceValue : null,
        'service_detail': _detailsController.text.trim(),
        'status': serviceStatus,
        'pricing_type': pricingType,
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
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(
            "Service Details",
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: Stack(
          children: [
            if (isLoading)
              const Center(
                  child: CircularProgressIndicator(color: kPrimaryBlue))
            else if (errorMessage.isNotEmpty)
              Center(
                child: Text(errorMessage,
                    style: GoogleFonts.poppins(color: Colors.red)),
              )
            else
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Service',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kPrimaryBlue,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name
                        _buildLabel("Service Name"),
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            icon: Icons.medical_services_outlined,
                          ),
                          style: GoogleFonts.roboto(),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Enter service name"
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel("Service Price"),
                            Row(
                              children: [
                                Text(
                                  "Range Pricing",
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Switch(
                                  value: isRangePricing,
                                  activeColor: kPrimaryBlue,
                                  onChanged: (val) {
                                    setState(() {
                                      isRangePricing = val;
                                      if (!val) _maxPriceController.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                decoration: _inputDecoration(
                                  prefixText: 'PHP',
                                  hintText:
                                      isRangePricing ? 'Min Price' : 'Price',
                                ),
                                style: GoogleFonts.roboto(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return 'Required';
                                  if (double.tryParse(v.trim()) == null)
                                    return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            if (isRangePricing) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("-",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _maxPriceController,
                                  decoration: _inputDecoration(
                                    prefixText: 'PHP',
                                    hintText: 'Max Price',
                                  ),
                                  style: GoogleFonts.roboto(),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Required';
                                    if (double.tryParse(v.trim()) == null)
                                      return 'Invalid';
                                    // Check if max > min handled in save
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Pricing Type
                        _buildLabel("Pricing Type"),
                        DropdownButtonFormField<String>(
                          value: pricingType,
                          decoration: _inputDecoration(
                              icon: Icons.price_change_outlined),
                          items: pricingTypes
                              .map((type) => DropdownMenuItem<String>(
                                    value: type['value'],
                                    child: Text(type['label']!,
                                        style: GoogleFonts.roboto()),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => pricingType = v ?? 'whole'),
                        ),
                        const SizedBox(height: 20),

                        // Details
                        _buildLabel("Service Details"),
                        TextFormField(
                          controller: _detailsController,
                          decoration: _inputDecoration(
                            icon: Icons.description_outlined,
                          ).copyWith(alignLabelWithHint: true),
                          style: GoogleFonts.roboto(),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 3,
                          maxLines: null,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Enter service details"
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // Status
                        _buildLabel("Status"),
                        DropdownButtonFormField<String>(
                          value: serviceStatus,
                          decoration:
                              _inputDecoration(icon: Icons.flag_outlined),
                          items: [
                            _buildItem('active', 'Active'),
                            _buildItem('inactive', 'Inactive'),
                          ],
                          onChanged: (v) =>
                              setState(() => serviceStatus = v ?? 'active'),
                        ),

                        const SizedBox(height: 32),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(
                                      color: kPrimaryBlue, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  foregroundColor: kPrimaryBlue,
                                ),
                                child: Text(
                                  "Cancel",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSaving ? null : _updateService,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryBlue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : Text(
                                        "Save Changes",
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold),
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
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          color: kTextDark,
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildItem(String value, String label) {
    return DropdownMenuItem(
      value: value,
      child: Text(label, style: GoogleFonts.roboto()),
    );
  }

  InputDecoration _inputDecoration({
    IconData? icon,
    String? prefixText,
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixStyle:
          GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true,
      fillColor: Colors.grey.shade50,
      prefixIcon: icon != null ? Icon(icon, color: kPrimaryBlue) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
