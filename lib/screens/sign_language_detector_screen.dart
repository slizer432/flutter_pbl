import 'dart:io';

import 'package:flutter/material.dart';

import '../services/mock_detector.dart';
import '../widgets/image_preview.dart';
import '../widgets/action_buttons.dart';
import '../widgets/detection_result.dart';

import 'package:image_picker/image_picker.dart';

class SignLanguageDetectorScreen extends StatefulWidget {
  const SignLanguageDetectorScreen({super.key});

  @override
  State<SignLanguageDetectorScreen> createState() =>
      _SignLanguageDetectorScreenState();
}

class _SignLanguageDetectorScreenState
    extends State<SignLanguageDetectorScreen> {
  File? _selectedImage;
  String? _detectionResult;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Language Detector',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.pan_tool,
                      size: 48,
                      color: Colors.deepPurple.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Deteksi Bahasa Isyarat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ambil foto tangan Anda dan deteksi gerakan bahasa isyarat secara real-time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Image preview (modular)
              ImagePreview(selectedImage: _selectedImage),
              const SizedBox(height: 24),

              // Buttons (modular)
              ActionButtons(
                isLoading: _isLoading,
                onTakePhoto: _takePhoto,
                onPickPhoto: _pickPhoto,
                onDetect: _selectedImage == null || _isLoading
                    ? null
                    : _detectSign,
              ),

              const SizedBox(height: 24),

              // Detection result (modular)
              DetectionResult(result: _detectionResult),

              const SizedBox(height: 16),

              // Info Cards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Tips Penggunaan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Pastikan pencahayaan cukup untuk hasil optimal\n'
                      '• Letakkan tangan di tengah frame\n'
                      '• Hindari gerakan blur\n'
                      '• Gunakan background yang kontras dengan tangan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _detectionResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error mengambil foto: $e')),
      );
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detectionResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error memilih foto: $e')),
      );
    }
  }

  Future<void> _detectSign() async {
    if (_selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await detectSignLanguage(_selectedImage!);
      setState(() => _detectionResult = result);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deteksi gagal: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
