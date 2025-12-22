import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'inference_isolate.dart';
import 'dart:async';

/*
 * 🔧 MIGRATION TO TFLITE_FLUTTER
 * 
 * Major architectural change:
 * - Uses background isolate (InferenceIsolate) for all heavy lifting
 * - Models loaded ONCE and reused (Actor pattern)
 * - Inference runs off the main thread
 * - Manual label mapping implemented in Dart
 */

/// Result from the validator model (teeth vs non-teeth)
class ValidatorResult {
  final bool isTeeth;
  final double confidence;
  final Duration inferenceTime;
  
  const ValidatorResult({
    required this.isTeeth,
    required this.confidence,
    required this.inferenceTime,
  });
  
  @override
  String toString() => 'ValidatorResult(isTeeth: $isTeeth, confidence: ${confidence.toStringAsFixed(2)}, time: ${inferenceTime.inMilliseconds}ms)';
}

/// Result from the disease classification model
class DiseaseResult {
  final String label;
  final double confidence;
  final List<PredictionScore> allPredictions;
  final Duration inferenceTime;
  
  const DiseaseResult({
    required this.label,
    required this.confidence,
    required this.allPredictions,
    required this.inferenceTime,
  });
  
  @override
  String toString() => 'DiseaseResult(label: $label, confidence: ${confidence.toStringAsFixed(2)}, time: ${inferenceTime.inMilliseconds}ms)';
}

/// Individual prediction score
class PredictionScore {
  final String label;
  final double confidence;
  
  const PredictionScore({
    required this.label,
    required this.confidence,
  });
  
  @override
  String toString() => '$label: ${(confidence * 100).toStringAsFixed(1)}%';
}

/// Combined result from the two-stage ML pipeline
class MLInferenceResult {
  final ValidatorResult? validatorResult;
  final DiseaseResult? diseaseResult;
  final MLInferenceStatus status;
  final String? errorMessage;
  final Duration totalTime;
  final bool fromCache;
  
  const MLInferenceResult({
    this.validatorResult,
    this.diseaseResult,
    required this.status,
    this.errorMessage,
    required this.totalTime,
    this.fromCache = false,
  });
  
  @override
  String toString() => 'MLInferenceResult(status: $status, totalTime: ${totalTime.inMilliseconds}ms, cached: $fromCache)';
}

enum MLInferenceStatus {
  loading,
  noTeethDetected,
  lowConfidence,
  unsupportedDisease,
  success,
  error,
}

/// Performance metrics for monitoring
class PerformanceMetrics {
  int totalInferences = 0;
  int successfulInferences = 0;
  int failedInferences = 0;
  Duration totalInferenceTime = Duration.zero;
  DateTime? lastInferenceTime;
  
  double get averageInferenceTime => 
    totalInferences > 0 ? totalInferenceTime.inMilliseconds / totalInferences : 0;
  
  double get successRate => 
    totalInferences > 0 ? (successfulInferences / totalInferences) * 100 : 0;
  
  void recordInference(Duration time, bool success) {
    totalInferences++;
    if (success) {
      successfulInferences++;
    } else {
      failedInferences++;
    }
    totalInferenceTime += time;
    lastInferenceTime = DateTime.now();
  }
  
  void reset() {
    totalInferences = 0;
    successfulInferences = 0;
    failedInferences = 0;
    totalInferenceTime = Duration.zero;
    lastInferenceTime = null;
  }
}

class MLInferenceService {
  // Confidence thresholds
  static const double _validatorConfidenceThreshold = 0.6; // 60% for teeth detection
  static const double _diseaseConfidenceThreshold = 0.5;   // 50% for disease classification
  
  // Supported disease labels (allowlist)
  // Maps directly to model output indices 0-6 if trained alphabetically or in specific order
  // Assuming order: ['CaS', 'CoS', 'Gum', 'MC', 'OC', 'OLP', 'OT']
  static const List<String> _diseaseLabels = [
    'CaS', 'CoS', 'Gum', 'MC', 'OC', 'OLP', 'OT'
  ];
  
  static const Set<String> _supportedDiseases = {
    'CaS', 'CoS', 'Gum', 'MC', 'OC', 'OLP', 'OT'
  };
  
  // Model configurations
  static const String _validatorModelPath = 'assets/teeth_validator.tflite';
  static const String _diseaseModelPath = 'assets/model.tflite';
  
  // Cache configuration
  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  // State management
  bool _modelsLoaded = false;
  bool _isInferenceRunning = false;
  
  // Background Isolate
  final InferenceIsolate _isolate = InferenceIsolate();
  
  // Result cache
  final Map<String, _CachedResult> _resultCache = {};
  
  // Performance tracking
  final PerformanceMetrics metrics = PerformanceMetrics();
  
  // Singleton pattern
  static final MLInferenceService _instance = MLInferenceService._internal();
  factory MLInferenceService() => _instance;
  MLInferenceService._internal();
  
  /// Initialize the ML models in background isolate
  Future<bool> initializeModels() async {
    if (_modelsLoaded) {
      debugPrint("✅ Models already loaded (background)");
      return true;
    }
    
    try {
      debugPrint("🔧 Initializing ML models in background isolate...");
      
      // Verify assets exist
      await _verifyAssets();
      
      // Start isolate and load models
      await _isolate.spawn();
      
      debugPrint("  - Loading model files into memory...");
      final validatorData = await rootBundle.load(_validatorModelPath);
      final diseaseData = await rootBundle.load(_diseaseModelPath);
      
      debugPrint("  - Sending model bytes to isolate...");
      final success = await _isolate.loadModels(
        validatorBytes: validatorData.buffer.asUint8List(),
        diseaseBytes: diseaseData.buffer.asUint8List(),
      );
      
      if (success) {
        _modelsLoaded = true;
        debugPrint("✅ ML models initialized successfully in background");
        return true;
      } else {
        debugPrint("❌ Failed to load models in isolate (Check logs for 'Isolate error')");
        return false;
      }
      
    } catch (e, stackTrace) {
      debugPrint("❌ Error initializing ML models: $e");
      debugPrint("Stack trace: $stackTrace");
      _modelsLoaded = false;
      return false;
    }
  }
  
  /// Verify that all required assets exist
  Future<void> _verifyAssets() async {
    final requiredAssets = [
      (_validatorModelPath, "Validator model"),
      (_diseaseModelPath, "Disease model"),
    ];
    
    for (var asset in requiredAssets) {
      try {
        await rootBundle.load(asset.$1);
        debugPrint("✓ ${asset.$2} found");
      } catch (e) {
        throw Exception("${asset.$2} not found at ${asset.$1}");
      }
    }
  }
  
  /// Run the two-stage ML inference pipeline
  Future<MLInferenceResult> runInference(
    String imagePath, {
    bool useCache = true,
    bool recordMetrics = true,
  }) async {
    if (_isInferenceRunning) {
      debugPrint("⚠️ Inference already running, please wait...");
      return const MLInferenceResult(
        status: MLInferenceStatus.error,
        errorMessage: "Another inference is already running",
        totalTime: Duration.zero,
      );
    }
    
    _isInferenceRunning = true;
    final startTime = DateTime.now();
    
    try {
      debugPrint("🚀 Starting two-stage ML inference pipeline (Background)...");
      debugPrint("📸 Image path: $imagePath");
      
      // Check cache first
      if (useCache) {
        final cachedResult = _getCachedResult(imagePath);
        if (cachedResult != null) {
          debugPrint("💾 Using cached result");
          return cachedResult;
        }
      }
      
      // Initialize models if needed
      if (!_modelsLoaded) {
        debugPrint("⚠️ Models not initialized, initializing now...");
        final initialized = await initializeModels();
        if (!initialized) {
          return MLInferenceResult(
            status: MLInferenceStatus.error,
            errorMessage: "Models not available",
            totalTime: DateTime.now().difference(startTime),
          );
        }
      }
      
      // Verify image file
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return MLInferenceResult(
          status: MLInferenceStatus.error,
          errorMessage: "Image file not found",
          totalTime: DateTime.now().difference(startTime),
        );
      }
      
      // STAGE 1: Validator model
      debugPrint("📊 STAGE 1: Running validator model (teeth detection)...");
      final validatorResult = await _runValidatorModel(imagePath);
      debugPrint("✅ Validator result: $validatorResult");
      
      // Check validator results
      if (!validatorResult.isTeeth) {
        debugPrint("⚠️ No teeth detected in image");
        final result = MLInferenceResult(
          validatorResult: validatorResult,
          status: MLInferenceStatus.noTeethDetected,
          totalTime: DateTime.now().difference(startTime),
        );
        if (recordMetrics) metrics.recordInference(result.totalTime, false);
        return result;
      }
      
      if (validatorResult.confidence < _validatorConfidenceThreshold) {
        debugPrint("⚠️ Low confidence from validator: ${validatorResult.confidence}");
        final result = MLInferenceResult(
          validatorResult: validatorResult,
          status: MLInferenceStatus.lowConfidence,
          totalTime: DateTime.now().difference(startTime),
        );
        if (recordMetrics) metrics.recordInference(result.totalTime, false);
        return result;
      }
      
      // STAGE 2: Disease classification
      debugPrint("📊 STAGE 2: Running disease classification model...");
      final diseaseResult = await _runDiseaseModel(imagePath);
      debugPrint("✅ Disease result: $diseaseResult");
      
      // Check disease results
      if (!_supportedDiseases.contains(diseaseResult.label)) {
        debugPrint("⚠️ Unsupported disease detected: ${diseaseResult.label}");
        final result = MLInferenceResult(
          validatorResult: validatorResult,
          diseaseResult: diseaseResult,
          status: MLInferenceStatus.unsupportedDisease,
          totalTime: DateTime.now().difference(startTime),
        );
        if (recordMetrics) metrics.recordInference(result.totalTime, false);
        return result;
      }
      
      if (diseaseResult.confidence < _diseaseConfidenceThreshold) {
        debugPrint("⚠️ Low confidence from disease model: ${diseaseResult.confidence}");
        final result = MLInferenceResult(
          validatorResult: validatorResult,
          diseaseResult: diseaseResult,
          status: MLInferenceStatus.lowConfidence,
          totalTime: DateTime.now().difference(startTime),
        );
        if (recordMetrics) metrics.recordInference(result.totalTime, false);
        return result;
      }
      
      // Success!
      debugPrint("🎉 Pipeline completed successfully!");
      final result = MLInferenceResult(
        validatorResult: validatorResult,
        diseaseResult: diseaseResult,
        status: MLInferenceStatus.success,
        totalTime: DateTime.now().difference(startTime),
      );
      
      // Cache the result
      if (useCache) {
        _cacheResult(imagePath, result);
      }
      
      if (recordMetrics) metrics.recordInference(result.totalTime, true);
      return result;
      
    } catch (e, stackTrace) {
      debugPrint("❌ Error during ML inference: $e");
      debugPrint("Stack trace: $stackTrace");
      
      final result = MLInferenceResult(
        status: MLInferenceStatus.error,
        errorMessage: e.toString(),
        totalTime: DateTime.now().difference(startTime),
      );
      if (recordMetrics) metrics.recordInference(result.totalTime, false);
      return result;
    } finally {
      _isInferenceRunning = false;
    }
  }

  /// Run the validator model (teeth vs non-teeth)
  Future<ValidatorResult> _runValidatorModel(String imagePath) async {
    final startTime = DateTime.now();
    try {
      final outputs = await _isolate.inferValidator(imagePath);
      
      if (outputs.isEmpty) {
        debugPrint("⚠️ Validator output is empty");
        return ValidatorResult(isTeeth: false, confidence: 0.0, inferenceTime: Duration.zero);
      }
      
      debugPrint("📊 Raw validator output: $outputs (Length: ${outputs.length})");
      
      // CASE 1: Single Output (Sigmoid) -> [prob_teeth]
      if (outputs.length == 1) {
        final prob = outputs[0];
        // Assumption: High value means Teeth (Class 1)
        // If prob > 0.5 -> Teeth
        final isTeeth = prob > 0.4; // Slightly lower threshold for safety
        
        debugPrint("🎯 Validator Prediction (Sigmoid): $prob -> ${isTeeth ? 'TEETH' : 'NON_TEETH'}");
        
        return ValidatorResult(
          isTeeth: isTeeth,
          confidence: prob,
          inferenceTime: DateTime.now().difference(startTime),
        );
      }
      
      // CASE 2: Multi Output (Softmax) -> [prob_non_teeth, prob_teeth]
      // Index 0 -> non_teeth
      // Index 1 -> teeth
      
      // Proper Argmax Logic
      int predictedIndex = 0;
      double maxVal = outputs[0];
      
      for (int i = 1; i < outputs.length; i++) {
        if (outputs[i] > maxVal) {
          maxVal = outputs[i];
          predictedIndex = i;
        }
      }
      
      // User Logic: index 1 is teeth
      final isTeeth = (predictedIndex == 1);
      final confidence = outputs[predictedIndex];
      
      debugPrint("🎯 Validator Prediction (Softmax): Index $predictedIndex (${isTeeth ? 'TEETH' : 'NON_TEETH'}) with confidence $confidence");
      
      return ValidatorResult(
        isTeeth: isTeeth,
        confidence: confidence,
        inferenceTime: DateTime.now().difference(startTime),
      );
      
    } catch (e, stackTrace) {
      debugPrint("❌ Validator failure: $e");
      debugPrint(stackTrace.toString());
      return ValidatorResult(isTeeth: false, confidence: 0.0, inferenceTime: Duration.zero);
    }
  }
  
  /// Run the disease classification model (7 classes)
  Future<DiseaseResult> _runDiseaseModel(String imagePath) async {
    final startTime = DateTime.now();
    try {
      final outputs = await _isolate.inferDisease(imagePath);
      
      // Map outputs to labels
      final allPredictions = <PredictionScore>[];
      
      for (int i = 0; i < outputs.length && i < _diseaseLabels.length; i++) {
        allPredictions.add(PredictionScore(
          label: _diseaseLabels[i],
          confidence: outputs[i],
        ));
      }
      
      // Sort
      allPredictions.sort((a, b) => b.confidence.compareTo(a.confidence));
      
      final top = allPredictions.isNotEmpty 
          ? allPredictions.first 
          : const PredictionScore(label: 'Unknown', confidence: 0.0);
          
      return DiseaseResult(
        label: top.label,
        confidence: top.confidence,
        allPredictions: allPredictions,
        inferenceTime: DateTime.now().difference(startTime),
      );
      
    } catch (e) {
      debugPrint("❌ Disease model failure: $e");
       return DiseaseResult(
        label: 'Unknown',
        confidence: 0.0,
        allPredictions: const [],
        inferenceTime: DateTime.now().difference(startTime),
      );
    }
  }
  
  /// Helper to dispose isolate
  void dispose() {
    _isolate.dispose();
  }

  // --- Cache Helpers ---
  
  MLInferenceResult? _getCachedResult(String imagePath) {
    final cached = _resultCache[imagePath];
    if (cached != null && !cached.isExpired) {
      return cached.result;
    }
    return null;
  }
  
  void _cacheResult(String imagePath, MLInferenceResult result) {
    if (_resultCache.length >= _maxCacheSize) {
      final oldestKey = _resultCache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
          .key;
      _resultCache.remove(oldestKey);
    }
    _resultCache[imagePath] = _CachedResult(result: result, timestamp: DateTime.now());
  }

  void clearCache() {
    _resultCache.clear();
    debugPrint("🧹 Cache cleared");
  }
}

class _CachedResult {
  final MLInferenceResult result;
  final DateTime timestamp;
  
  _CachedResult({required this.result, required this.timestamp});
  
  bool get isExpired => DateTime.now().difference(timestamp) > MLInferenceService._cacheExpiry;
}
