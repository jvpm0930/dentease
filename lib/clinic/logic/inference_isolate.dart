import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Commands sent to the isolate
enum InferenceCommandType {
  loadModels,
  inferValidator,
  inferDisease,
  dispose,
}

/// Data payload for commands
class InferenceCommand {
  final InferenceCommandType type;
  final String? imagePath;
  final Uint8List? validatorModelBytes;
  final Uint8List? diseaseModelBytes;
  final SendPort? responsePort;

  InferenceCommand({
    required this.type,
    this.imagePath,
    this.validatorModelBytes,
    this.diseaseModelBytes,
    this.responsePort,
  });
}

/// Response from the isolate
class InferenceResponse {
  final bool success;
  final dynamic result;
  final String? error;

  InferenceResponse({
    required this.success,
    this.result,
    this.error,
  });
}

/// Manages the background inference isolate
class InferenceIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _responseStream = StreamController<InferenceResponse>.broadcast();

  // Initialize the isolate
  Future<void> spawn() async {
    if (_isolate != null) return;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntry,
      receivePort.sendPort,
    );
    
    // Wait for the isolate to send its SendPort
    _sendPort = await receivePort.first as SendPort;
  }

  // Load models in the background
  Future<bool> loadModels({
    required Uint8List validatorBytes,
    required Uint8List diseaseBytes,
  }) async {
    if (_sendPort == null) await spawn();
    
    final responsePort = ReceivePort();
    _sendPort!.send(InferenceCommand(
      type: InferenceCommandType.loadModels,
      validatorModelBytes: validatorBytes,
      diseaseModelBytes: diseaseBytes,
      responsePort: responsePort.sendPort,
    ));

    final response = await responsePort.first as InferenceResponse;
    if (!response.success && response.error != null) {
      // Propagate error message if possible, or just log
      print("Isolate error: ${response.error}"); 
    }
    return response.success;
  }

  // Run validator inference
  Future<List<double>> inferValidator(String imagePath) async {
    if (_sendPort == null) throw Exception("Isolate not spawned");

    final responsePort = ReceivePort();
    _sendPort!.send(InferenceCommand(
      type: InferenceCommandType.inferValidator,
      imagePath: imagePath,
      responsePort: responsePort.sendPort,
    ));

    final response = await responsePort.first as InferenceResponse;
    if (!response.success) throw Exception(response.error);
    return (response.result as List).cast<double>();
  }

  // Run disease inference
  Future<List<double>> inferDisease(String imagePath) async {
    if (_sendPort == null) throw Exception("Isolate not spawned");

    final responsePort = ReceivePort();
    _sendPort!.send(InferenceCommand(
      type: InferenceCommandType.inferDisease,
      imagePath: imagePath,
      responsePort: responsePort.sendPort,
    ));

    final response = await responsePort.first as InferenceResponse;
    if (!response.success) throw Exception(response.error);
    return (response.result as List).cast<double>();
  }

  void dispose() {
    _sendPort?.send(InferenceCommand(type: InferenceCommandType.dispose));
    _isolate?.kill();
    _isolate = null;
    _sendPort = null;
    _responseStream.close();
  }

  // --- Background Isolate Logic ---
  
  static void _isolateEntry(SendPort mainSendPort) async {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    Interpreter? validatorInterpreter;
    Interpreter? diseaseInterpreter;

    await for (final InferenceCommand command in receivePort) {
      if (command.type == InferenceCommandType.dispose) {
        validatorInterpreter?.close();
        diseaseInterpreter?.close();
        Isolate.exit();
      }

      try {
        if (command.type == InferenceCommandType.loadModels) {
          // Initialize interpreters from bytes
          if (command.validatorModelBytes != null) {
            validatorInterpreter = Interpreter.fromBuffer(command.validatorModelBytes!);
          }
          if (command.diseaseModelBytes != null) {
            diseaseInterpreter = Interpreter.fromBuffer(command.diseaseModelBytes!);
            diseaseInterpreter.resizeInputTensor(0, [1, 150, 150, 3]);
            diseaseInterpreter.allocateTensors();
          }
          
          command.responsePort?.send(InferenceResponse(success: true));
        } 
        
        else if (command.type == InferenceCommandType.inferValidator || 
                 command.type == InferenceCommandType.inferDisease) {
          
          if (command.imagePath == null) {
            throw Exception("Image path is null");
          }

          final interpreter = command.type == InferenceCommandType.inferValidator
              ? validatorInterpreter
              : diseaseInterpreter;

          if (interpreter == null) {
            throw Exception("Model not loaded");
          }


          // Preprocessing
          List<List<List<List<double>>>> input;
          
          if (interpreter == validatorInterpreter) {
             input = await _preprocessForValidator(command.imagePath!);
          } else {
             input = await _preprocessForDisease(command.imagePath!);
          }
          
          // Inference
          // Assuming output shape based on model type
          // Validator: [1, 2] -> [[non_teeth_prob, teeth_prob]] usually 
          // Disease: [1, 7]
          
          // We need to inspect output shape to be safe, but for now we allocate based on expected size
          // Tensor buffers are better but simple list works for simple models
          
          var outputShape = interpreter.getOutputTensor(0).shape;
          // print("Isolate: ${command.type} output shape: $outputShape"); // Debug log
          
          if (outputShape.isEmpty) {
             throw Exception("Output shape is empty");
          }
          
          // Allocate output buffer
          // If shape is [1, N], we need List<List<double>>
          // But tflite_flutter's `run` method is flexible. 
          // To avoid 'reshape' conflict and complexity, let's manually create the structure.
          
          var outputList = List.generate(
            outputShape[0], 
            (_) => List.filled(outputShape[1], 0.0)
          );
          
          interpreter.run(input, outputList);
          
          // 🔎 DEBUG: Verify correct input tensor shape before inference
          print(
            command.type == InferenceCommandType.inferDisease
                ? "🧪 Disease input tensor shape: ${interpreter.getInputTensor(0).shape}"
                : "🧪 Validator input tensor shape: ${interpreter.getInputTensor(0).shape}"
          );

        
          
          // Flatten result for transport
          final flatResult = (outputList[0] as List).cast<double>();
          
          command.responsePort?.send(InferenceResponse(
            success: true,
            result: flatResult,
          ));
        }
      } catch (e) {
        command.responsePort?.send(InferenceResponse(
          success: false,
          error: e.toString(),
        ));
      }
    }
  }

  // --- Preprocessing Helpers ---

  // Validator: 224x224, Normalized [-1, 1]
  static Future<List<List<List<List<double>>>>> _preprocessForValidator(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) throw Exception("Could not decode image");

    // Resize to 224x224
    final resized = img.copyResize(image, width: 224, height: 224);

    // Normalize to [-1, 1] float32
    // Shape: [1, 224, 224, 3]
    
    var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
      var pixel = resized.getPixel(x, y);
      return [
        (img.getRed(pixel) - 127.5) / 127.5,   // R
        (img.getGreen(pixel) - 127.5) / 127.5, // G
        (img.getBlue(pixel) - 127.5) / 127.5,  // B
      ];
    })));

    return input;
  }

  // Disease: 150x150, Normalized [0, 1] (pixel / 255.0)
  static Future<List<List<List<List<double>>>>> _preprocessForDisease(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) throw Exception("Could not decode image");

    // Resize to 150x150
    final resized = img.copyResize(image, width: 150, height: 150);

    // Normalize to [0, 1] float32
    // Shape: [1, 150, 150, 3]
    
    var input = List.generate(1, (i) => List.generate(150, (y) => List.generate(150, (x) {
      var pixel = resized.getPixel(x, y);
      return [
        img.getRed(pixel) / 255.0,   // R
        img.getGreen(pixel) / 255.0, // G
        img.getBlue(pixel) / 255.0,  // B
      ];
    })));

    return input;
  }
}

