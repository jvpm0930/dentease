import 'package:dentease/common/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class DentistAddService extends StatefulWidget {
  final String clinicId;

  const DentistAddService({super.key, required this.clinicId});

  @override
  _DentistAddServiceState createState() => _DentistAddServiceState();
}

class _DentistAddServiceState extends State<DentistAddService> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  final servNameController = TextEditingController();
  final servPriceMinController = TextEditingController();
  final servPriceMaxController = TextEditingController();
  final servDetController = TextEditingController();
  final customTagController = TextEditingController();
  late TextEditingController clinicController;

  bool isRangePricing = false; // Toggle for range pricing

  List<Map<String, dynamic>> diseases = []; // store disease_id + name
  String? selectedDiseaseId; // store UUID

  // Pricing Type Options
  String? selectedPricingType;
  static const List<Map<String, String>> pricingTypes = [
    {
      'value': 'whole',
      'label': 'Whole Treatment',
      'description': 'Fixed price for the entire treatment'
    },
    {
      'value': 'per_tooth',
      'label': 'Per Tooth',
      'description': 'Price charged for each tooth treated'
    },
    {
      'value': 'per_session',
      'label': 'Per Session',
      'description': 'Price per treatment session/visit'
    },
    {
      'value': 'per_unit',
      'label': 'Per Unit',
      'description': 'Price per unit (e.g., per filling, per crown)'
    },
    {
      'value': 'per_area',
      'label': 'Per Area',
      'description': 'Price per affected area/quadrant'
    },
  ];

  // Hybrid Tagging State
  List<String> selectedSystemTags = [];
  List<String> customTags = [];

  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kBackground = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    clinicController = TextEditingController(text: widget.clinicId);
    selectedPricingType = 'whole'; // Default to whole treatment
    _fetchDiseases();
  }

  @override
  void dispose() {
    servNameController.dispose();
    servPriceMinController.dispose();
    servPriceMaxController.dispose();
    servDetController.dispose();
    customTagController.dispose();
    clinicController.dispose();
    super.dispose();
  }

  ///  Fetch diseases (id + name)
  Future<void> _fetchDiseases() async {
    try {
      final response =
          await supabase.from('disease').select('disease_id, disease_name');

      // Convert to List<Map<String, dynamic>>
      final fetchedDiseases = (response as List)
          .map((d) => {
                'id': d['disease_id'].toString(),
                'name': d['disease_name'].toString(),
              })
          .toList();

      //  Sort alphabetically by name
      fetchedDiseases.sort((a, b) => a['name']!.compareTo(b['name']!));

      //  Ensure "None" is always at the top
      final noneItem = fetchedDiseases.firstWhere(
        (d) => d['name']!.toLowerCase() == 'none',
        orElse: () => {},
      );

      if (noneItem.isNotEmpty) {
        fetchedDiseases.remove(noneItem);
        fetchedDiseases.insert(0, noneItem);
      }

      // Update state
      setState(() {
        diseases = fetchedDiseases;
      });
    } catch (e) {
      _showSnackbar("Error fetching diseases");
    }
  }

  /// 🔹 Insert service
  Future<void> signUp() async {
    try {
      final servname = servNameController.text.trim();
      final servpriceMinStr = servPriceMinController.text.trim();
      final servpriceMaxStr = servPriceMaxController.text.trim();
      final servdet = servDetController.text.trim();
      final clinicId = clinicController.text.trim();

      if (servname.isEmpty ||
          servpriceMinStr.isEmpty ||
          selectedDiseaseId == null) {
        _showSnackbar('Please fill in all required fields.');
        return;
      }

      if (selectedPricingType == null) {
        _showSnackbar('Please select a pricing type.');
        return;
      }

      // Parse min price as number
      final servpriceMin = double.tryParse(servpriceMinStr);
      if (servpriceMin == null || servpriceMin <= 0) {
        _showSnackbar('Please enter a valid minimum price.');
        return;
      }

      // Parse max price if range pricing is enabled
      double? servpriceMax;
      if (isRangePricing && servpriceMaxStr.isNotEmpty) {
        servpriceMax = double.tryParse(servpriceMaxStr);
        if (servpriceMax == null || servpriceMax <= 0) {
          _showSnackbar('Please enter a valid maximum price.');
          return;
        }
        if (servpriceMax <= servpriceMin) {
          _showSnackbar('Maximum price must be greater than minimum price.');
          return;
        }
      }

      // Combine tags
      final List<String> medicalTags = [...selectedSystemTags, ...customTags];

      await supabase.from('services').insert({
        'service_name': servname,
        'service_price': servpriceMin, // Min price (or only price if not range)
        if (servpriceMax != null)
          'max_price': servpriceMax, // Max price if range
        'pricing_type':
            selectedPricingType, // New field: per_tooth, whole, etc.
        'service_detail': servdet,
        'clinic_id': clinicId,
        'disease_id': selectedDiseaseId, //  send disease_id (UUID)
        'medical_tags': medicalTags, // Hybrid tags
        'status': 'active', // Default to active
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Service added successfully!',
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.green.shade600),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: GoogleFonts.poppins())));
  }

  // --- Hybrid Tagging UI Helpers ---

  void _toggleSystemTag(String key) {
    setState(() {
      if (selectedSystemTags.contains(key)) {
        selectedSystemTags.remove(key);
      } else {
        selectedSystemTags.add(key);
      }
    });
  }

  void _addCustomTag() {
    final text = customTagController.text.trim();
    if (text.isNotEmpty && !customTags.contains(text)) {
      setState(() {
        customTags.add(text);
        customTagController.clear();
      });
    }
  }

  void _removeCustomTag(String tag) {
    setState(() {
      customTags.remove(tag);
    });
  }

  Widget _buildTargetedProblemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Targeted Problems",
          style: GoogleFonts.poppins(
            color: kPrimaryBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // System Chips (AI Conditions)
        Text(
          "Common Conditions (AI)",
          style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: AppConstants.aiConditionLabels.entries.map((entry) {
            final key = entry.key;
            final label = entry.value;
            final isSelected = selectedSystemTags.contains(key);

            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => _toggleSystemTag(key),
              selectedColor: kPrimaryBlue.withValues(alpha: 0.2),
              checkmarkColor: kPrimaryBlue,
              labelStyle: GoogleFonts.roboto(
                color: isSelected ? kPrimaryBlue : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                    color: isSelected ? kPrimaryBlue : Colors.grey.shade300),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 15),

        // Custom Tags Input
        Text(
          "Other Conditions",
          style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customTagController,
                decoration: InputDecoration(
                  hintText: 'Type a condition...',
                  hintStyle: GoogleFonts.roboto(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kPrimaryBlue),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: kPrimaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: kPrimaryBlue),
                onPressed: _addCustomTag,
              ),
            ),
          ],
        ),

        if (customTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: customTags.map((tag) {
              return Chip(
                label: Text(tag),
                backgroundColor: Colors.grey.shade100,
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeCustomTag(tag),
                labelStyle: GoogleFonts.roboto(color: Colors.black87),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: Text(
            "Add Service",
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildTextField(
                  servNameController,
                  'Service Name',
                  Icons.medical_services_outlined,
                ),
                const SizedBox(height: 16),

                // Price Input - Numbers only
                _buildPriceField(),
                const SizedBox(height: 16),

                // Pricing Type Dropdown
                _buildPricingTypeDropdown(),
                const SizedBox(height: 16),

                // Targeted Problems
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildTargetedProblemsSection(),
                ),

                const SizedBox(height: 16),

                _buildTextField(servDetController, 'Service Details',
                    Icons.info_outline_rounded,
                    isMultiline: true),
                const SizedBox(height: 16),

                /// Dropdown showing disease_name but storing disease_id
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedDiseaseId,
                    items: diseases
                        .map((disease) => DropdownMenuItem<String>(
                              value: disease['id'] as String, // UUID
                              child: Text(disease['name']), // Show name
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDiseaseId = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: "Select Oral Problem",
                      labelStyle: GoogleFonts.roboto(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.coronavirus_outlined,
                          color: kPrimaryBlue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildSignUpButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool readOnly = false,
    bool isPassword = false,
    bool isMultiline = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        style: GoogleFonts.roboto(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.roboto(color: Colors.grey),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, color: kPrimaryBlue),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        keyboardType:
            isMultiline ? TextInputType.multiline : TextInputType.text,
        maxLines: isMultiline ? null : 1, // null = grow dynamically
        minLines: isMultiline ? 3 : 1,
      ),
    );
  }

  Widget _buildPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Range pricing toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Range',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Switch(
                value: isRangePricing,
                onChanged: (value) {
                  setState(() {
                    isRangePricing = value;
                    if (!value) {
                      servPriceMaxController.clear();
                    }
                  });
                },
                activeColor: kPrimaryBlue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Price inputs
        Row(
          children: [
            // Min price (or single price)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: servPriceMinController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: GoogleFonts.roboto(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: isRangePricing
                        ? 'Min Price (PHP)'
                        : 'Service Price (PHP)',
                    hintStyle: GoogleFonts.roboto(color: Colors.grey),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('PHP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryBlue,
                            )),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

            // Max price (only if range pricing enabled)
            if (isRangePricing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '-',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: servPriceMaxController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: GoogleFonts.roboto(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Max Price (PHP)',
                      hintStyle: GoogleFonts.roboto(color: Colors.grey),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('PHP',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              )),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        if (isRangePricing)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Price will display as: PHP${servPriceMinController.text.isEmpty ? "100" : servPriceMinController.text} - PHP${servPriceMaxController.text.isEmpty ? "200" : servPriceMaxController.text}',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: kPrimaryBlue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPricingTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: selectedPricingType,
        items: pricingTypes
            .map((type) => DropdownMenuItem<String>(
                  value: type['value'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        type['label']!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedPricingType = value;
          });
        },
        decoration: InputDecoration(
          labelText: "Pricing Type",
          labelStyle: GoogleFonts.roboto(color: Colors.grey[600]),
          helperText: _getPricingTypeDescription(),
          helperStyle: GoogleFonts.roboto(
            color: kPrimaryBlue,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          prefixIcon:
              const Icon(Icons.price_change_outlined, color: kPrimaryBlue),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  String _getPricingTypeDescription() {
    final type = pricingTypes.firstWhere(
      (t) => t['value'] == selectedPricingType,
      orElse: () => {'description': ''},
    );
    return type['description'] ?? '';
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: kPrimaryBlue.withValues(alpha: 0.4),
        ),
        child: Text(
          'Add Service',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
