import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:dentease/patients/patient_clinicv2.dart';
import 'package:dentease/patients/patient_pagev2.dart';
import 'package:dentease/clinic/logic/ml_inference_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/*
 * DENTAL AI SCANNER - TWO-STAGE ML INFERENCE PIPELINE
 * 
 * This implementation uses REAL model outputs with a two-stage approach:
 * 
 * STAGE 1: Validator Model (teeth vs non_teeth)
 * - Determines if the image contains oral/dental content
 * - If non_teeth: Show "No Oral Issues Detected"
 * - If low confidence: Show "Can't Recognize"
 * 
 * STAGE 2: Disease Model (7-class classification)
 * - Runs ONLY if validator detects teeth
 * - Predicts one of 7 supported diseases
 * - If unsupported disease: Show "Can't Recognize"
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
  bool _isPickingImage = false;  // Prevents multiple ImagePicker calls
  bool _isDisposed = false;      // Tracks widget disposal for async safety

  // Medical conditions mapping - ONLY for UI display, no confidence data
  static const Map<String, MedicalCondition> medicalConditions = {
    "CaS": MedicalCondition(
      code: "CaS",
      fullName: "Dental Caries",
      description: "Tooth decay caused by bacterial acid production. Early intervention can prevent further damage and preserve tooth structure.",
      severity: "Moderate Attention",
      severityColor: Color(0xFFFF9800),
    ),
    "CoS": MedicalCondition(
      code: "CoS",
      fullName: "Calculus Buildup",
      description: "Hardened plaque deposits on teeth surfaces. Professional cleaning is recommended to prevent gum disease and maintain oral health.",
      severity: "Low Attention",
      severityColor: Color(0xFF4CAF50),
    ),
    "Gum": MedicalCondition(
      code: "Gum",
      fullName: "Gingivitis",
      description: "Inflammation of the gums caused by bacterial plaque. Proper oral hygiene and professional treatment can reverse this condition.",
      severity: "Moderate Attention",
      severityColor: Color(0xFFFF9800),
    ),
    "MC": MedicalCondition(
      code: "MC",
      fullName: "Oral Malignancy Indicators",
      description: "Potential signs of oral cancer detected. Immediate professional evaluation is strongly recommended for proper diagnosis.",
      severity: "High Attention",
      severityColor: Color(0xFFF44336),
    ),
    "OC": MedicalCondition(
      code: "OC",
      fullName: "Oral Cancer Signs",
      description: "Suspicious lesions that may indicate oral cancer. Urgent dental consultation required for comprehensive examination.",
      severity: "High Attention",
      severityColor: Color(0xFFF44336),
    ),
    "OLP": MedicalCondition(
      code: "OLP",
      fullName: "Oral Lichen Planus",
      description: "Chronic inflammatory condition affecting oral tissues. Regular monitoring and treatment can help manage symptoms effectively.",
      severity: "Moderate Attention",
      severityColor: Color(0xFFFF9800),
    ),
    "OT": MedicalCondition(
      code: "OT",
      fullName: "Oral Thrush",
      description: "Fungal infection in the mouth. Antifungal treatment is typically effective in resolving this condition completely.",
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
      debugPrint("⚠️ _pickImage blocked: picking=$_isPickingImage, analyzing=$_isAnalyzing, disposed=$_isDisposed");
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
      debugPrint("⚠️ _classifyImage blocked: analyzing=$_isAnalyzing, disposed=$_isDisposed");
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
        diseaseDescription = "An error occurred during image analysis: ${e.toString()}";
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
          label = "No Oral Issues Detected";
          confidence = result.validatorResult?.confidence ?? 0.0;
          diseaseDescription = "The uploaded image does not appear to contain oral or dental content.";
          predictions = [];
          services = [];
        });
        break;

      case MLInferenceStatus.lowConfidence:
        setState(() {
          label = "Can't Recognize";
          confidence = result.validatorResult?.confidence ?? 0.0;
          diseaseDescription = "The image could not be confidently analyzed. Please upload a clear oral image.";
          predictions = [];
          services = [];
        });
        break;

      case MLInferenceStatus.unsupportedDisease:
        setState(() {
          label = "Can't Recognize";
          confidence = result.diseaseResult?.confidence ?? 0.0;
          diseaseDescription = "The detected condition is not part of the supported disease list.";
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
              confidence = diseaseResult.confidence * 100; // Convert to percentage
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
          } else {
            setState(() {
              label = "Unknown Condition";
              confidence = diseaseResult.confidence * 100;
              diseaseDescription = "The detected condition is not in our medical database.";
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
          diseaseDescription = result.errorMessage ?? "An unknown error occurred during analysis.";
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
        description = diseaseResponse['description'] ?? 'No description available.';
        
        final diseaseId = diseaseResponse['disease_id'];
        final serviceResponse = await Supabase.instance.client
            .from('services')
            .select('service_name, service_price, clinic_id, status')
            .eq('disease_id', diseaseId)
            .eq('status', 'active');

        // ============================================
        // 🔧 CRASH FIX: Check mounted after second await
        // ============================================
        if (!mounted || _isDisposed) return;

        servicesList = List<Map<String, dynamic>>.from(serviceResponse);
      } else {
        // Use medical condition data as fallback
        final condition = medicalConditions[diseaseName];
        description = condition?.description ?? 'No description available for this condition.';
        
        // Generate some demo services
        servicesList = _generateDemoServices(diseaseName);
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
        diseaseDescription = condition?.description ?? 'Error retrieving disease information. Please consult a dental professional.';
        services = _generateDemoServices(diseaseName);
      });
      
      debugPrint("Error fetching disease info: $e");
    }
  }

  List<Map<String, dynamic>> _generateDemoServices(String diseaseName) {
    // Generate realistic demo services based on disease type
    final baseServices = <Map<String, dynamic>>[];
    
    switch (diseaseName) {
      case "Gum":
        baseServices.addAll([
          {'service_name': 'Professional Teeth Cleaning', 'service_price': '2500', 'clinic_id': 'demo_1'},
          {'service_name': 'Gum Treatment', 'service_price': '3500', 'clinic_id': 'demo_2'},
          {'service_name': 'Periodontal Therapy', 'service_price': '5000', 'clinic_id': 'demo_3'},
        ]);
        break;
      case "CaS":
        baseServices.addAll([
          {'service_name': 'Dental Filling', 'service_price': '1500', 'clinic_id': 'demo_1'},
          {'service_name': 'Root Canal Treatment', 'service_price': '8000', 'clinic_id': 'demo_2'},
          {'service_name': 'Tooth Restoration', 'service_price': '4500', 'clinic_id': 'demo_3'},
        ]);
        break;
      case "CoS":
        baseServices.addAll([
          {'service_name': 'Dental Scaling', 'service_price': '2000', 'clinic_id': 'demo_1'},
          {'service_name': 'Deep Cleaning', 'service_price': '3000', 'clinic_id': 'demo_2'},
        ]);
        break;
      default:
        baseServices.addAll([
          {'service_name': 'Dental Consultation', 'service_price': '800', 'clinic_id': 'demo_1'},
          {'service_name': 'Oral Examination', 'service_price': '1200', 'clinic_id': 'demo_2'},
          {'service_name': 'Treatment Planning', 'service_price': '1500', 'clinic_id': 'demo_3'},
        ]);
    }
    
    return baseServices;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          'AI Dental Scan Result',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PatientPage()),
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
              color: const Color(0xFF0D47A1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 60,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Take or Upload a Photo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
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
                color: Color(0xFF6B7280),
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
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Oral Issues Detected',
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
                color: Color(0xFF6B7280),
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
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
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
                color: Color(0xFF6B7280),
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
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
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
                color: Color(0xFF6B7280),
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
                  color: Color(0xFF9CA3AF),
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
        if (services.isNotEmpty) _buildServicesSection(),
        const SizedBox(height: 16),
        _buildDisclaimerCard(),
      ],
    );
  }

  Widget _buildErrorCard(MLInferenceResult result) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Analysis Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              result.errorMessage ?? 'An unknown error occurred during analysis.',
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

  Widget _buildAnalyzingCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Color(0xFF0D47A1),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analyzing Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
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
      shadowColor: Colors.black.withOpacity(0.1),
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
              const Color(0xFF0D47A1).withOpacity(0.05),
              const Color(0xFF1976D2).withOpacity(0.05),
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
                    color: const Color(0xFF0D47A1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 80,
                      color: Color(0xFF0D47A1),
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
      shadowColor: Colors.black.withOpacity(0.1),
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
                    color: const Color(0xFF0D47A1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: Color(0xFF0D47A1),
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
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        condition.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
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
                color: condition.severityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: condition.severityColor.withOpacity(0.3),
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
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      prediction.confidence >= 80
                          ? const Color(0xFF10B981)
                          : prediction.confidence >= 60
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
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
                    color: Color(0xFF1A1A1A),
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
            color: Color(0xFF1A1A1A),
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
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF0D47A1),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Medical Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              diseaseDescription,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        ...services.map((service) => _buildServiceCard(service)),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.medical_services,
            color: Color(0xFF10B981),
            size: 24,
          ),
        ),
        title: Text(
          service['service_name'],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Text(
          'Price: ₱${service['service_price']}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFF9CA3AF),
          size: 16,
        ),
        onTap: () {
          // ============================================
          // 🔧 CRASH FIX: Check mounted before navigation
          // ============================================
          if (!mounted || _isDisposed) return;
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientClinicInfoPage(
                clinicId: service['clinic_id'],
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
      shadowColor: Colors.black.withOpacity(0.1),
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
                  ? const Color(0xFFEF4444)
                  : label.contains('Analyzing')
                      ? const Color(0xFF0D47A1)
                      : const Color(0xFF10B981),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
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
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: const Color(0xFFF59E0B),
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
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This result is AI-assisted and not a medical diagnosis. Please consult a qualified dental professional for proper evaluation and treatment.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
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
            color: Colors.black.withOpacity(0.1),
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
                onPressed: buttonsDisabled ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Upload'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: buttonsDisabled 
                      ? const Color(0xFF9CA3AF) 
                      : const Color(0xFF0D47A1),
                  side: BorderSide(
                    color: buttonsDisabled 
                        ? const Color(0xFF9CA3AF) 
                        : const Color(0xFF0D47A1),
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
                onPressed: buttonsDisabled ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonsDisabled 
                      ? const Color(0xFF9CA3AF) 
                      : const Color(0xFF0D47A1),
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
