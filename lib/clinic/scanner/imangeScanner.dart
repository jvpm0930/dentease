import 'dart:io';

import 'package:dentease/theme/app_theme.dart';
import 'package:dentease/utils/currency_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dentease/clinic/logic/ml_inference_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/patients/patient_booking.dart';
import 'package:dentease/patients/patient_main_layout.dart';

/*
 * DENTAL AI SCANNER - TWO-STAGE ML INFERENCE PIPELINE
 * 
 * This implementation uses REAL model outputs with a two-stage approach:
 * 
 * STAGE 1: Validator Model (teeth vs non_teeth)
 * - Determines if the image contains oral/dental content
 * - If non_teeth: Show "Can't Recognize"
 * - If low confidence: Show "Can't Classified"
 * 
 * STAGE 2: Disease Model (7-class classification)
 * - Runs ONLY if validator detects teeth
 * - Predicts one of 7 supported diseases
 * - If unsupported disease: Show "Can't Classified"
 * 
 * Key Features:
 * - No mock/demo/fake prediction data
 * - Real TensorFlow Lite model integration
 * - Proper conditional execution flow
 * - Clean UI state management
 * - Professional medical presentation
 * 
 * ============================================
 * 🔧 CRASH FIX UPDATES (Lifecycle Safety):
 * ============================================
 * 1. Added _isPickingImage lock to prevent multiple picker calls
 * 2. Added _isDisposed flag to track widget disposal
 * 3. Added comprehensive mounted checks after EVERY await
 * 4. Buttons disabled during analysis/picking operations
 * 5. Safe dispose() that cancels all pending async work
 * ============================================
 */

// Medical condition data model - ONLY for UI mapping, no fake data
class MedicalCondition {
  final String code;
  final String fullName;
  final String description;
  final String severity;
  final Color severityColor;

  const MedicalCondition({
    required this.code,
    required this.fullName,
    required this.description,
    required this.severity,
    required this.severityColor,
  });
}

// Real ML model prediction result - DEPRECATED, use MLInferenceService instead
class ModelPrediction {
  final String label;
  final double confidence;

  const ModelPrediction({
    required this.label,
    required this.confidence,
  });
}

class ImageClassifierScreen extends StatefulWidget {
  const ImageClassifierScreen({super.key});

  @override
  State<ImageClassifierScreen> createState() => _ImageClassifierScreenState();
}

class _ImageClassifierScreenState extends State<ImageClassifierScreen> {
  File? filePath;
  String label = '';
  double confidence = 0.0;
  String diseaseDescription = '';
  List<Map<String, dynamic>> services = [];
  List<ModelPrediction> predictions = []; // DEPRECATED - kept for compatibility

  // ML Inference Service
  final MLInferenceService _mlService = MLInferenceService();
  MLInferenceResult? _currentResult;
  bool _isAnalyzing = false;

  // ============================================
  // 🔧 CRASH FIX: Lifecycle safety flags
  // ============================================
  bool _isPickingImage = false; // Prevents multiple ImagePicker calls
  bool _isDisposed = false; // Tracks widget disposal for async safety

  // Medical conditions mapping - ONLY for UI display, no confidence data
  static const Map<String, MedicalCondition> medicalConditions = {
    "CaS": MedicalCondition(
      code: "CaS",
      fullName: "Dental Caries",
      description:
          "Tooth decay caused by bacterial acid production. Early intervention can prevent further damage and preserve tooth structure.",
      severity: "Moderate Attention",
      severityColor: Color(0xFFFF9800),
    ),
    "CoS": MedicalCondition(
      code: "CoS",
      fullName: "Calculus Buildup",
      description:
          "Hardened plaque deposits on teeth surfaces. Professional cleaning is recommended to prevent gum disease and maintain oral health.",
      severity: "Low Attention",
      severityColor: Color(0xFF4CAF50),
    ),
    "Gum": MedicalCondition(
      code: "Gum",
      fullName: "Gingivitis",
      description:
          "Inflammation of the gums caused by bacterial plaque. Proper oral hygiene and professional treatment can reverse this condition.",
      severity: "Moderate Attention",
      severityColor: Color(0xFFFF9800),
    ),
    "MC": MedicalCondition(
      code: "MC",
      fullName: "Oral Malignancy Indicators",
      description:
          "Potential signs of oral cancer detected. Immediate professional evaluation is strongly recommended for proper diagnosis.",
      severity: "High Attention",
      severityColor: Color(0xFFF44336),
    ),
    "OC": MedicalCondition(
      code: "OC",
      fullName: "Oral Cancer Signs",
      description:
          "Suspicious lesions that may indicate oral cancer. Urgent dental consultation required for comprehensive examination.",
      severity: "High Attention",
      severityColor: Color(0xFFF44336),
    ),
    "OLP": MedicalCondition(
      code: "OLP",
      fullName: "Oral Lichen Planus",
      description:
          "Chronic inflammatory condition affecting oral tissues. Regular monitoring and treatment can help manage symptoms effectively.",
      severity: "Moderate Attention",
      severityColor: Color(0xFFFF9800),
    ),
    "OT": MedicalCondition(
      code: "OT",
      fullName: "Oral Thrush",
      description:
          "Fungal infection in the mouth. Antifungal treatment is typically effective in resolving this condition completely.",
      severity: "Low Attention",
      severityColor: Color(0xFF4CAF50),
    ),
  };

  @override
  void initState() {
    super.initState();
    _initializeMLService();
  }

  Future<void> _initializeMLService() async {
    // 🔧 CRASH FIX: Check disposal before async work
    if (_isDisposed) return;

    try {
      debugPrint("Initializing ML inference service...");
      await _mlService.initializeModels();

      // 🔧 CRASH FIX: Check mounted after await
      if (!mounted || _isDisposed) return;

      debugPrint("ML service initialized successfully");
    } catch (e) {
      debugPrint("Error initializing ML service: $e");
    }
  }

  /// Pick image from camera or gallery
  /// 🔧 CRASH FIX: Added comprehensive guards against concurrent calls
  Future<void> _pickImage(ImageSource source) async {
    // ============================================
    // 🔧 CRASH FIX: Prevent multiple picker calls
    // ============================================
    // Guard against: concurrent picks, analysis in progress, widget disposed
    if (_isPickingImage || _isAnalyzing || _isDisposed || !mounted) {
      debugPrint(
          "⚠️ _pickImage blocked: picking=$_isPickingImage, analyzing=$_isAnalyzing, disposed=$_isDisposed");
      return;
    }

    _isPickingImage = true;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      // ============================================
      // 🔧 CRASH FIX: Check mounted after await
      // ============================================
      // Widget may have been disposed while picker was open
      if (!mounted || _isDisposed) {
        debugPrint("⚠️ Widget disposed during image picking");
        return;
      }

      if (image == null) {
        debugPrint("📷 No image selected");
        return;
      }

      setState(() {
        filePath = File(image.path);
        label = '';
        confidence = 0.0;
        diseaseDescription = '';
        services = [];
        predictions = [];
        _currentResult = null;
      });

      // ============================================
      // 🔧 CRASH FIX: Only classify if safe to do so
      // ============================================
      if (!_isAnalyzing && mounted && !_isDisposed) {
        await _classifyImage(image.path);
      }
    } catch (e) {
      debugPrint("❌ Error picking image: $e");

      // 🔧 CRASH FIX: Safe error handling
      if (mounted && !_isDisposed) {
        setState(() {
          label = "Error";
          diseaseDescription = "Failed to pick image: ${e.toString()}";
        });
      }
    } finally {
      // ============================================
      // 🔧 CRASH FIX: Always reset lock in finally
      // ============================================
      _isPickingImage = false;
    }
  }

  /// Classify the selected image using ML inference
  /// 🔧 CRASH FIX: Added comprehensive lifecycle guards
  Future<void> _classifyImage(String path) async {
    // ============================================
    // 🔧 CRASH FIX: Prevent concurrent analysis
    // ============================================
    if (_isAnalyzing || !mounted || _isDisposed) {
      debugPrint(
          "⚠️ _classifyImage blocked: analyzing=$_isAnalyzing, disposed=$_isDisposed");
      return;
    }

    setState(() {
      _isAnalyzing = true;
      label = "Analyzing...";
      confidence = 0;
      diseaseDescription = "AI is analyzing your dental image. Please wait...";
      predictions = [];
      services = [];
      _currentResult = null;
    });

    try {
      debugPrint("Starting two-stage ML inference pipeline...");

      // Run the two-stage ML inference pipeline
      final result = await _mlService.runInference(path);

      // ============================================
      // 🔧 CRASH FIX: Check mounted after await
      // ============================================
      if (!mounted || _isDisposed) {
        debugPrint("⚠️ Widget disposed during ML inference");
        return;
      }

      setState(() {
        _currentResult = result;
        _isAnalyzing = false;
      });

      // Process the result based on status
      _processMLResult(result);
    } catch (e) {
      // ============================================
      // 🔧 CRASH FIX: Safe error handling
      // ============================================
      if (!mounted || _isDisposed) return;

      setState(() {
        _isAnalyzing = false;
        _currentResult = MLInferenceResult(
          status: MLInferenceStatus.error,
          errorMessage: e.toString(),
          totalTime: Duration.zero,
        );
        label = "Analysis Error";
        diseaseDescription =
            "An error occurred during image analysis: ${e.toString()}";
        predictions = [];
        services = [];
      });
      debugPrint("Classification error: $e");
    }
  }

  /// Process ML inference result and update UI accordingly
  /// 🔧 CRASH FIX: Added disposal check
  void _processMLResult(MLInferenceResult result) {
    // ============================================
    // 🔧 CRASH FIX: Comprehensive safety check
    // ============================================
    if (!mounted || _isDisposed) return;

    switch (result.status) {
      case MLInferenceStatus.loading:
        // Should not reach here as loading is handled in _classifyImage
        break;

      case MLInferenceStatus.noTeethDetected:
        setState(() {
          label = "Can't Recognize";
          confidence = result.validatorResult?.confidence ?? 0.0;
          diseaseDescription =
              "The uploaded image does not appear to contain oral or dental content.";
          predictions = [];
          services = [];
        });
        break;

      case MLInferenceStatus.lowConfidence:
        setState(() {
          label = "Can't Classified";
          confidence = result.validatorResult?.confidence ?? 0.0;
          diseaseDescription =
              "The image could not be confidently analyzed. Please upload a clear oral image.";
          predictions = [];
          services = [];
        });
        break;

      case MLInferenceStatus.unsupportedDisease:
        setState(() {
          label = "Can't Classified";
          confidence = result.diseaseResult?.confidence ?? 0.0;
          diseaseDescription =
              "The detected condition is not part of the supported disease list.";
          predictions = [];
          services = [];
        });
        break;

      case MLInferenceStatus.success:
        if (result.diseaseResult != null) {
          final diseaseResult = result.diseaseResult!;
          final condition = medicalConditions[diseaseResult.label];

          if (condition != null) {
            setState(() {
              label = diseaseResult.label;
              confidence =
                  diseaseResult.confidence * 100; // Convert to percentage
              diseaseDescription = condition.description;

              // Create ModelPrediction for compatibility with existing UI
              predictions = [
                ModelPrediction(
                  label: diseaseResult.label,
                  confidence: diseaseResult.confidence * 100,
                )
              ];
            });

            // Fetch additional information
            _fetchDiseaseDescription(diseaseResult.label);
            _fetchRecommendedServices(diseaseResult.label);
          } else {
            setState(() {
              label = "Unknown Condition";
              confidence = diseaseResult.confidence * 100;
              diseaseDescription =
                  "The detected condition is not in our medical database.";
              predictions = [];
              services = [];
            });
          }
        }
        break;

      case MLInferenceStatus.error:
        setState(() {
          label = "Analysis Error";
          confidence = 0.0;
          diseaseDescription = result.errorMessage ??
              "An unknown error occurred during analysis.";
          predictions = [];
          services = [];
        });
        break;
    }
  }

  /// Fetch disease description from database
  /// 🔧 CRASH FIX: Added comprehensive lifecycle guards
  Future<void> _fetchDiseaseDescription(String diseaseName) async {
    // ============================================
    // 🔧 CRASH FIX: Early exit if disposed
    // ============================================
    if (_isDisposed || !mounted) return;

    try {
      // First check if there are any approved clinics
      final clinicsResponse = await Supabase.instance.client
          .from('clinics')
          .select('clinic_id')
          .eq('status', 'approved');

      if (!mounted || _isDisposed) return;

      // First try to get from database
      final diseaseResponse = await Supabase.instance.client
          .from('disease')
          .select('disease_id, description')
          .ilike('disease_name', diseaseName.trim())
          .maybeSingle();

      // ============================================
      // 🔧 CRASH FIX: Check mounted after await
      // ============================================
      if (!mounted || _isDisposed) return;

      String description;
      List<Map<String, dynamic>> servicesList = [];

      if (diseaseResponse != null) {
        // Found in database
        description =
            diseaseResponse['description'] ?? 'No description available.';

        // Only fetch services if there are approved clinics
        if (clinicsResponse.isNotEmpty) {
          final approvedClinicIds = clinicsResponse
              .map((clinic) => clinic['clinic_id'] as String)
              .toList();

          final diseaseId = diseaseResponse['disease_id'];
          final serviceResponse = await Supabase.instance.client
              .from('services')
              .select(
                  'service_name, service_price, clinic_id, status, service_id, service_detail')
              .eq('disease_id', diseaseId)
              .eq('status', 'active')
              .inFilter('clinic_id', approvedClinicIds);

          // ============================================
          // 🔧 CRASH FIX: Check mounted after second await
          // ============================================
          if (!mounted || _isDisposed) return;

          servicesList = List<Map<String, dynamic>>.from(serviceResponse);
        }
      } else {
        // Use medical condition data as fallback
        final condition = medicalConditions[diseaseName];
        description = condition?.description ??
            'No description available for this condition.';

        // Don't generate demo services - leave empty if no clinics
        servicesList = [];
      }

      setState(() {
        diseaseDescription = description;
        services = servicesList;
      });
    } catch (e) {
      // ============================================
      // 🔧 CRASH FIX: Safe error handling
      // ============================================
      if (!mounted || _isDisposed) return;

      // Fallback to medical condition data on error
      final condition = medicalConditions[diseaseName];
      setState(() {
        diseaseDescription = condition?.description ??
            'Error retrieving disease information. Please consult a dental professional.';
        services = []; // Don't show demo services on error
      });

      debugPrint("Error fetching disease info: $e");
    }
  }

  Future<void> _fetchRecommendedServices(String detectedKey) async {
    if (_isDisposed || !mounted) return;

    try {
      debugPrint("🔍 Fetching services for detected condition: $detectedKey");

      // First check if there are any approved clinics
      final clinicsResponse = await Supabase.instance.client
          .from('clinics')
          .select('clinic_id')
          .eq('status', 'approved');

      if (!mounted || _isDisposed) return;

      // If no approved clinics exist, don't show any services
      if (clinicsResponse.isEmpty) {
        debugPrint("⚠️ No approved clinics found");
        setState(() {
          services = [];
        });
        return;
      }

      // Get clinic IDs for filtering services
      final approvedClinicIds = clinicsResponse
          .map((clinic) => clinic['clinic_id'] as String)
          .toList();

      debugPrint("✅ Found ${approvedClinicIds.length} approved clinics");

      // Query services with clinic name included
      // Fix: Use proper PostgreSQL array contains operator
      final response = await Supabase.instance.client
          .from('services')
          .select(
              'service_id, service_name, service_price, service_detail, clinic_id, medical_tags, clinics(clinic_name)')
          .filter('medical_tags', 'cs',
              '{$detectedKey}') // PostgreSQL array contains operator
          .inFilter('clinic_id', approvedClinicIds)
          .eq('status', 'active')
          .eq('is_active', true);

      debugPrint("🔍 Query executed: medical_tags contains '$detectedKey'");
      debugPrint("📊 Raw response: $response");

      if (!mounted || _isDisposed) return;

      List<Map<String, dynamic>> servicesList =
          List<Map<String, dynamic>>.from(response);

      debugPrint(
          "🎯 Found ${servicesList.length} matching services for condition: $detectedKey");

      // If no services found with exact match, try broader search
      if (servicesList.isEmpty) {
        debugPrint("🔄 No exact matches found, trying broader search...");

        // Try searching for services that might treat this condition
        // Look for common dental service categories
        final broadSearchTerms = _getBroadSearchTerms(detectedKey);

        for (String searchTerm in broadSearchTerms) {
          final broadResponse = await Supabase.instance.client
              .from('services')
              .select(
                  'service_id, service_name, service_price, service_detail, clinic_id, medical_tags, clinics(clinic_name)')
              .filter('medical_tags', 'cs', '{$searchTerm}')
              .inFilter('clinic_id', approvedClinicIds)
              .eq('status', 'active')
              .eq('is_active', true);

          debugPrint(
              "🔍 Broad search query: medical_tags contains '$searchTerm'");
          debugPrint("📊 Broad search response: $broadResponse");

          if (broadResponse.isNotEmpty) {
            servicesList = List<Map<String, dynamic>>.from(broadResponse);
            debugPrint(
                "✅ Found ${servicesList.length} services with broader search term: $searchTerm");
            break;
          }
        }

        // If still no results, try searching by service name/description
        if (servicesList.isEmpty) {
          debugPrint("🔄 Trying service name/description search...");
          final nameSearchTerms = _getServiceNameSearchTerms(detectedKey);

          for (String searchTerm in nameSearchTerms) {
            final nameResponse = await Supabase.instance.client
                .from('services')
                .select(
                    'service_id, service_name, service_price, service_detail, clinic_id, clinics(clinic_name)')
                .or('service_name.ilike.%$searchTerm%,service_detail.ilike.%$searchTerm%,service_description.ilike.%$searchTerm%')
                .inFilter('clinic_id', approvedClinicIds)
                .eq('status', 'active')
                .eq('is_active', true);

            if (nameResponse.isNotEmpty) {
              servicesList = List<Map<String, dynamic>>.from(nameResponse);
              debugPrint(
                  "✅ Found ${servicesList.length} services with name search: $searchTerm");
              break;
            }
          }
        }
      }

      setState(() {
        services = servicesList;
      });

      if (servicesList.isEmpty) {
        debugPrint("⚠️ No services found for condition: $detectedKey");
      }
    } catch (e) {
      debugPrint("❌ Error fetching recommended services: $e");
      // Set empty services on error instead of showing demo services
      if (!mounted || _isDisposed) return;
      setState(() {
        services = [];
      });
    }
  }

  /// Get broader search terms for a detected condition
  List<String> _getBroadSearchTerms(String detectedKey) {
    switch (detectedKey) {
      case 'CaS': // Calculus
        return ['cleaning', 'scaling', 'calculus', 'tartar', 'plaque'];
      case 'CoS': // Caries
        return ['filling', 'cavity', 'caries', 'restoration', 'decay'];
      case 'Gum': // Gum disease
        return ['gum', 'periodontal', 'gingivitis', 'cleaning', 'scaling'];
      case 'MC': // Mouth Cancer
        return ['oral', 'cancer', 'biopsy', 'screening', 'examination'];
      case 'OC': // Oral Cancer
        return ['oral', 'cancer', 'biopsy', 'screening', 'examination'];
      case 'OLP': // Oral Lichen Planus
        return ['oral', 'lichen', 'planus', 'treatment', 'medication'];
      case 'OT': // Oral Thrush
        return ['oral', 'thrush', 'fungal', 'antifungal', 'treatment'];
      default:
        return ['general', 'consultation', 'examination', 'checkup'];
    }
  }

  /// Get service name search terms for a detected condition
  List<String> _getServiceNameSearchTerms(String detectedKey) {
    switch (detectedKey) {
      case 'CaS': // Calculus
        return ['cleaning', 'scaling', 'polish'];
      case 'CoS': // Caries
        return ['filling', 'restoration', 'composite'];
      case 'Gum': // Gum disease
        return ['gum', 'periodontal', 'deep cleaning'];
      case 'MC': // Mouth Cancer
      case 'OC': // Oral Cancer
        return ['oral screening', 'cancer screening', 'biopsy'];
      case 'OLP': // Oral Lichen Planus
        return ['oral medicine', 'specialist consultation'];
      case 'OT': // Oral Thrush
        return ['oral medicine', 'antifungal'];
      default:
        return ['consultation', 'examination'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'AI Dental Scan Result',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: filePath == null ? _buildInitialState() : _buildResultState(),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 60,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Take or Upload a Photo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Capture a clear image of your teeth for AI analysis',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textGrey,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageCard(),
          const SizedBox(height: 20),
          if (_isAnalyzing) ...[
            _buildAnalyzingCard(),
          ] else if (_currentResult != null) ...[
            _buildResultCard(_currentResult!),
          ] else if (predictions.isNotEmpty) ...[
            _buildPrimaryDiagnosisCard(),
            const SizedBox(height: 16),
            if (predictions.length > 1) _buildAlternativeDiagnosisSection(),
            const SizedBox(height: 16),
            _buildDescriptionCard(),
            const SizedBox(height: 16),
            if (services.isNotEmpty) _buildServicesSection(),
            const SizedBox(height: 16),
            _buildDisclaimerCard(),
          ] else if (label.isNotEmpty) ...[
            _buildStatusCard(),
          ],
          const SizedBox(height: 100), // Bottom padding for floating button
        ],
      ),
    );
  }

  Widget _buildResultCard(MLInferenceResult result) {
    switch (result.status) {
      case MLInferenceStatus.loading:
        return _buildAnalyzingCard();

      case MLInferenceStatus.noTeethDetected:
        return _buildNoTeethDetectedCard(result);

      case MLInferenceStatus.lowConfidence:
        return _buildLowConfidenceCard(result);

      case MLInferenceStatus.unsupportedDisease:
        return _buildUnsupportedDiseaseCard(result);

      case MLInferenceStatus.success:
        return _buildSuccessResultCard(result);

      case MLInferenceStatus.error:
        return _buildErrorCard(result);
    }
  }

  Widget _buildNoTeethDetectedCard(MLInferenceResult result) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Can\'t Recognize',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'The uploaded image does not appear to contain oral or dental content.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (result.validatorResult != null) ...[
              const SizedBox(height: 16),
              Text(
                'Confidence: ${(result.validatorResult!.confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLowConfidenceCard(MLInferenceResult result) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.help_outline,
                size: 48,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Can\'t Recognize',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'The image could not be confidently analyzed. Please upload a clear oral image.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (result.validatorResult != null) ...[
              const SizedBox(height: 16),
              Text(
                'Confidence: ${(result.validatorResult!.confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedDiseaseCard(MLInferenceResult result) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.help_outline,
                size: 48,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Can\'t Recognize',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'The detected condition is not part of the supported disease list.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (result.diseaseResult != null) ...[
              const SizedBox(height: 16),
              Text(
                'Detected: ${result.diseaseResult!.label} (${(result.diseaseResult!.confidence * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessResultCard(MLInferenceResult result) {
    if (result.diseaseResult == null) return const SizedBox.shrink();

    final diseaseResult = result.diseaseResult!;
    final condition = medicalConditions[diseaseResult.label];

    if (condition == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildPrimaryDiagnosisCard(),
        const SizedBox(height: 16),
        _buildDescriptionCard(),
        const SizedBox(height: 16),
        _buildServicesSection(),
        const SizedBox(height: 16),
        _buildDisclaimerCard(),
      ],
    );
  }

  Widget _buildErrorCard(MLInferenceResult result) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Analysis Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              result.errorMessage ??
                  'An unknown error occurred during analysis.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analyzing Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              diseaseDescription,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.05),
              AppTheme.accentBlue.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: filePath != null
              ? Image.file(
                  filePath!,
                  fit: BoxFit.cover,
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 80,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPrimaryDiagnosisCard() {
    if (predictions.isEmpty) return const SizedBox.shrink();

    final prediction = predictions.first;
    final condition = medicalConditions[prediction.label];

    if (condition == null) return const SizedBox.shrink();

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medical_services_outlined,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Primary Diagnosis',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        condition.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: condition.severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: condition.severityColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                condition.severity,
                style: TextStyle(
                  color: condition.severityColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Confidence Level',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: prediction.confidence / 100,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      prediction.confidence >= 80
                          ? AppTheme.successColor
                          : prediction.confidence >= 60
                              ? AppTheme.warningColor
                              : AppTheme.errorColor,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${prediction.confidence.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeDiagnosisSection() {
    if (predictions.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Other Possible Conditions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: predictions.skip(1).take(2).map((prediction) {
            final condition = medicalConditions[prediction.label];

            if (condition == null) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.dividerColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    condition.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${prediction.confidence.toStringAsFixed(1)}% confidence',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Medical Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              diseaseDescription,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    return Column(
      children: [
        const Text(
          'Recommended Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        if (services.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.softBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: [
                Icon(Icons.medical_services_outlined,
                    color: AppTheme.textGrey, size: 32),
                const SizedBox(height: 8),
                Text(
                  "No clinics available yet",
                  style: TextStyle(
                      color: AppTheme.textDark, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "Please wait for clinics to register and get approved by admin.",
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    // Navigate to patient dashboard properly
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PatientMainLayout()),
                      (route) => false,
                    );
                  },
                  child: const Text("Go to Dashboard"),
                )
              ],
            ),
          )
        else
          ...services.map((service) => _buildServiceCard(service)),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    // Extract clinic name from joined data
    final clinicData = service['clinics'] as Map<String, dynamic>?;
    final clinicName =
        clinicData?['clinic_name'] as String? ?? 'Unknown Clinic';

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.medical_services,
            color: AppTheme.successColor,
            size: 24,
          ),
        ),
        title: Text(
          service['service_name'],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.local_hospital,
                    size: 14, color: AppTheme.primaryBlue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    clinicName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.formatPesoWithText(service['service_price']),
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text("Book Now",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
        onTap: () {
          // ============================================
          // 🔧 CRASH FIX: Check mounted before navigation
          // ============================================
          if (!mounted || _isDisposed) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientBookingPage(
                clinicId: service['clinic_id'].toString(),
                serviceId: service['service_id']?.toString() ?? 'unknown',
                serviceName: service['service_name'].toString(),
                servicePrice: service['service_price'].toString(),
                serviceDetail: service['service_detail']?.toString() ??
                    'No description available',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              label.contains('Error') || label.contains('Invalid')
                  ? Icons.error_outline
                  : label.contains('Analyzing')
                      ? Icons.analytics_outlined
                      : Icons.check_circle_outline,
              size: 48,
              color: label.contains('Error') || label.contains('Invalid')
                  ? AppTheme.errorColor
                  : label.contains('Analyzing')
                      ? AppTheme.primaryBlue
                      : AppTheme.successColor,
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              diseaseDescription,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: AppTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medical Disclaimer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This result is AI-assisted and not a medical diagnosis. Please consult a qualified dental professional for proper evaluation and treatment.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom action buttons
  /// 🔧 CRASH FIX: Buttons disabled during active operations
  Widget _buildBottomActions() {
    // ============================================
    // 🔧 CRASH FIX: Disable buttons during operations
    // ============================================
    final bool buttonsDisabled = _isAnalyzing || _isPickingImage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                // 🔧 CRASH FIX: Disable button during operations
                onPressed: buttonsDisabled
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Upload'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: buttonsDisabled
                      ? AppTheme.textGrey
                      : AppTheme.primaryBlue,
                  side: BorderSide(
                    color: buttonsDisabled
                        ? AppTheme.textGrey
                        : AppTheme.primaryBlue,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                // 🔧 CRASH FIX: Disable button during operations
                onPressed: buttonsDisabled
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonsDisabled
                      ? AppTheme.textGrey
                      : AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: buttonsDisabled ? 0 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dispose resources and cancel pending work
  /// 🔧 CRASH FIX: Enhanced dispose to signal all async operations to stop
  @override
  void dispose() {
    // ============================================
    // 🔧 CRASH FIX: Signal all async operations to stop
    // ============================================
    _isDisposed = true;
    _isPickingImage = false;
    _isAnalyzing = false;

    // Clean up ML service resources
    _mlService.dispose();

    super.dispose();
  }
}
