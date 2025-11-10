import 'dart:io';
import 'dart:developer' as devtools;

import 'package:dentease/patients/patient_clinicv2.dart';
import 'package:dentease/patients/patient_pagev2.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final validDiseases = const [
    "Chipped or Fractured",
    "Gingivitis",
    "Healthy Tooth",
    "Malocclusion",
    "Plaque and Tartar",
    "Tooth Caries",
    "Tooth Discoloration",
    "Tooth Erosion",
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
        numThreads: 1,
        isAsset: true,
        useGpuDelegate: false,
      );
    } catch (e) {
      devtools.log("Error loading TFLite model");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      filePath = File(image.path);
      label = '';
      confidence = 0.0;
      diseaseDescription = '';
      services = [];
    });

    await _classifyImage(image.path);
  }

  // 1) Helper: clean TFLite label like "0 gingivitis" -> "gingivitis"
  String _cleanLabel(String raw) {
    final s = raw.trim();
    final sp = s.split(' ');
    if (sp.isNotEmpty && int.tryParse(sp.first) != null && sp.length > 1) {
      return s.substring(s.indexOf(' ') + 1).trim();
    }
    return s;
  }

// 2) Classify with typical MobileNet/EfficientNet normalization
  Future<void> _classifyImage(String path) async {
    try {
      final recognitions = await Tflite.runModelOnImage(
        path: path,
        imageMean: 127.5, // typical CNN normalization
        imageStd: 127.5,
        numResults: 3,
        threshold: 0.05, // score filter before sorting
        asynch: true,
      );

      if (!mounted) return;

      if (recognitions == null || recognitions.isEmpty) {
        setState(() {
          label = "No detection";
          diseaseDescription = "Please try again with a clearer image.";
        });
        return;
      }

      // Take top-1
      final result = recognitions.first;
      final detectedLabelRaw = result['label'].toString();
      final detectedLabel = _cleanLabel(detectedLabelRaw); // <-- sanitize
      final detectedConfidence = (result['confidence'] * 100);

      // Relax threshold to 90%
      const minConfidence = 90.0;

      if (validDiseases
              .map((e) => e.toLowerCase())
              .contains(detectedLabel.toLowerCase()) &&
          detectedConfidence >= minConfidence) {
        setState(() {
          label = detectedLabel;
          confidence = detectedConfidence;
        });
        await _fetchDiseaseDescription(detectedLabel);
      } else {
        setState(() {
          label = "No Oral Problems Detected";
          confidence = detectedConfidence;
          diseaseDescription =
              "Try again with a clearer image or better lighting.";
          services = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        label = "Error";
        diseaseDescription = "Failed to run model. Please try again.";
      });
    }
  }

// 3) Case-insensitive disease lookup
  Future<void> _fetchDiseaseDescription(String diseaseName) async {
    try {
      final diseaseResponse = await Supabase.instance.client
          .from('disease')
          .select('disease_id, description')
          .ilike('disease_name', diseaseName.trim()) // <-- case-insensitive
          .maybeSingle();

      if (!mounted) return;

      if (diseaseResponse == null) {
        setState(() {
          diseaseDescription = "No description found.";
          services = [];
        });
        return;
      }

      final diseaseId = diseaseResponse['disease_id'];
      final serviceResponse = await Supabase.instance.client
          .from('services')
          .select('service_name, service_price, clinic_id, status')
          .eq('disease_id', diseaseId)
          .eq('status', 'active');

      setState(() {
        diseaseDescription =
            diseaseResponse['description'] ?? 'No description available.';
        services = List<Map<String, dynamic>>.from(serviceResponse);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        diseaseDescription = "Error retrieving disease info.";
        services = [];
      });
    }
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const SizedBox(height: 60),
            const Text(
              "Tooth Scanner",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Card(
                    elevation: 20,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 320,
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          Container(
                            height: 300,
                            width: 300,
                            decoration: BoxDecoration(
                              color: const Color(0xFF103D7E),
                              borderRadius: BorderRadius.circular(12),
                              image: filePath == null
                                  ? const DecorationImage(
                                      image: AssetImage('assets/logo.png'),
                                    )
                                  : null,
                            ),
                            child: filePath == null
                                ? const SizedBox.shrink()
                                : Image.file(filePath!, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  "Scan Result: $label",
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                if (confidence > 0)
                                  Text(
                                    "Accuracy: ${confidence.toStringAsFixed(0)}%",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                const SizedBox(height: 12),
                                Card(
                                  elevation: 10,
                                  margin: const EdgeInsets.only(top: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Container(
                                    width: 300,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Description:",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          diseaseDescription,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (services.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  const Text(
                                    "Available Services:",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  Column(
                                    children: services.map((service) {
                                      return Card(
                                        elevation: 6,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6, horizontal: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.medical_services,
                                            color: Color(0xFF103D7E),
                                          ),
                                          title: Text(service['service_name']),
                                          subtitle: Text(
                                              "Price: ₱${service['service_price']}"),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PatientClinicInfoPage(
                                                  clinicId:
                                                      service['clinic_id'],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF103D7E),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PatientPage()),
                    ),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Image.asset(
                      'assets/icons/scan.png',
                      width: 30,
                      height: 30,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    child: const Text(
                      "UPLOAD",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
