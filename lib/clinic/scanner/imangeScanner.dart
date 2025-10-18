import 'dart:io';

import 'package:dentease/patients/patient_clinicv2.dart';
import 'package:dentease/patients/patient_pagev2.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:developer' as devtools;

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

  List<Map<String, dynamic>> services = []; // store services for this disease

  Future<void> fetchDiseaseDescription(String label) async {
    final diseaseResponse = await Supabase.instance.client
        .from('disease')
        .select('disease_id, description')
        .eq('disease_name', label.trim())
        .single();

    final diseaseId = diseaseResponse['disease_id'];

    // Fetch only active services
    final serviceResponse = await Supabase.instance.client
        .from('services')
        .select('service_name, service_price, clinic_id, status')
        .eq('disease_id', diseaseId)
        .eq('status', 'active'); 

    if (mounted) {
      setState(() {
        diseaseDescription =
            diseaseResponse['description'] ?? 'No description found.';
        services = List<Map<String, dynamic>>.from(serviceResponse);
      });
    }
    }

  


  Future<void> _tfLteInit() async {
    String? res = await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
        numThreads: 1, // defaults to 1
        isAsset:
            true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate:
            false // defaults to false, set to true to use GPU delegate
        );
  }

  pickImageGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    var imageMap = File(image.path);

    setState(() {
      filePath = imageMap;
    });

    var recognitions = await Tflite.runModelOnImage(
        path: image.path, // required
        imageMean: 0.0, // defaults to 117.0
        imageStd: 255.0, // defaults to 1.0
        numResults: 2, // defaults to 5
        threshold: 0.2, // defaults to 0.1
        asynch: true // defaults to true
        );

    if (recognitions == null) {
      devtools.log("recognitions is Null");
      return;
    }
    devtools.log(recognitions.toString());
    setState(() {
      confidence = (recognitions[0]['confidence'] * 100);
      label = recognitions[0]['label'].toString();

      // Only accept if it's one of your known diseases
      const validDiseases = [
        "Chipped or Fractured",
        "Gingivitis",
        "Malocclusion",
        "Plaque and Tartar",
        "Tooth Caries",
        "Tooth Discoloration",
        "Tooth Erosion",
      ];

      // Confidence threshold (e.g., 50%)
      const double confidenceThreshold = 50.0;

      if (validDiseases
              .map((e) => e.toLowerCase())
              .contains(label.toLowerCase()) &&
          confidence >= confidenceThreshold) {
        fetchDiseaseDescription(label);
      } else {
        label = "Not a tooth disease";
        confidence = 0.0;
        diseaseDescription =
            "Try again with a clearer image.";
      }
    });
  }

  pickImageCamera() async {
    final ImagePicker picker = ImagePicker();
// Pick an image.
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    var imageMap = File(image.path);

    setState(() {
      filePath = imageMap;
    });

    var recognitions = await Tflite.runModelOnImage(
        path: image.path, // required
        imageMean: 0.0, // defaults to 117.0
        imageStd: 255.0, // defaults to 1.0
        numResults: 2, // defaults to 5
        threshold: 0.2, // defaults to 0.1
        asynch: true // defaults to true
        );

    if (recognitions == null) {
      devtools.log("recognitions is Null");
      return;
    }
    devtools.log(recognitions.toString());
    setState(() {
      confidence = (recognitions[0]['confidence'] * 100);
      label = recognitions[0]['label'].toString();

      // Only accept if it's one of your known diseases
      const validDiseases = [
        "Chipped or Fractured",
        "Gingivitis",
        "Malocclusion",
        "Plaque and Tartar",
        "Tooth Caries",
        "Tooth Discoloration",
        "Tooth Erosion",
      ];

      // Confidence threshold (e.g., 50%)
      const double confidenceThreshold = 50.0;

      if (validDiseases
              .map((e) => e.toLowerCase())
              .contains(label.toLowerCase()) &&
          confidence >= confidenceThreshold) {
        fetchDiseaseDescription(label);
      } else {
        label = "Not a tooth disease";
        confidence = 0.0;
        diseaseDescription =
            "Try again with a clearer image.";
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    Tflite.close();
  }

  @override
  void initState() {
    super.initState();
    _tfLteInit();
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
                  child: Column(
                    children: [
                      Card(
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
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(12),
                                  image: const DecorationImage(
                                      image: AssetImage('assets/logo.png')),
                                ),
                                child: filePath == null
                                    ? const Text('')
                                    : Image.file(
                                        filePath!,
                                        fit: BoxFit.fill,
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Text(
                                      "Result: $label",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "The Accuracy is ${confidence.toStringAsFixed(0)}%",
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 12),
                                      Card(
                                        elevation: 10,
                                        margin: const EdgeInsets.only(top: 20),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15)),
                                        child: Container(
                                          width: 300,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(15),
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
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
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
                                                  color: Colors.blue),
                                              title:
                                                  Text(service['service_name']),
                                              subtitle: Text(
                                                  "Price: ₱${service['service_price']}"),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PatientClinicInfoPage(
                                                            clinicId: service[
                                                                'clinic_id']),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      )

                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PatientPage()),
                      );
                    },
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      pickImageCamera();
                    },
                    icon: Image.asset(
                      'assets/icons/scan.png',
                      width: 30, // Adjust size
                      height: 30,
                      color: Colors.white, // Optional: make it match other icons
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      pickImageGallery();
                    },
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
