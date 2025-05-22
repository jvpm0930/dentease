import 'package:camera/camera.dart';
import 'package:dentease/clinic/scanner/result.dart';
import 'package:flutter/material.dart';

class ToothScannerPage extends StatefulWidget {
  const ToothScannerPage({super.key});

  @override
  State<ToothScannerPage> createState() => _ToothScannerPageState();
}

class _ToothScannerPageState extends State<ToothScannerPage> {
  late List<CameraDescription> cameras;
  CameraController? controller;
  bool isLoading = true;
  bool isFrontCamera = false;
  bool flashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    _setupCamera(_getCamera(isFrontCamera));
  }

  CameraDescription _getCamera(bool useFrontCamera) {
    return cameras.firstWhere(
      (camera) =>
          camera.lensDirection ==
          (useFrontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
    );
  }

  Future<void> _setupCamera(CameraDescription cameraDescription) async {
    controller = CameraController(cameraDescription, ResolutionPreset.high,
        enableAudio: false);
    await controller!.initialize();
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleFlash() async {
    if (controller == null) return;
    flashOn = !flashOn;
    await controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _takePicture() async {
    if (!controller!.value.isInitialized) return;

    final XFile file = await controller!.takePicture();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToothScanResultPage(imagePath: file.path),
      ),
    );
  }

  void _uploadImage() {
    // TODO: Add upload from gallery
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload from gallery not implemented yet')),
    );
  }

  void _switchCamera() async {
    setState(() {
      isLoading = true;
      isFrontCamera = !isFrontCamera;
    });
    await controller?.dispose();
    _setupCamera(_getCamera(isFrontCamera));
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(controller!),

          // Top bar (Back, Flash, Switch camera)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.switch_camera,
                      color: Colors.white, size: 30),
                ),
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    flashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),

          // Scan box
          Center(
            child: Container(
              width: 250,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Bottom controls (Back, Capture, Upload)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // cancel button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      const Text('CANCEL', style: TextStyle(color: Colors.white)),
                ),

                // Capture Button
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 4),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.blue, size: 35),
                  ),
                ),

                // UPLOAD button
                ElevatedButton(
                  onPressed: _uploadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('UPLOAD',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
