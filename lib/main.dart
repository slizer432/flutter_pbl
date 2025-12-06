import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASL Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ASLDetectionPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ASLDetectionPage extends StatefulWidget {
  const ASLDetectionPage({super.key});

  @override
  State<ASLDetectionPage> createState() => _ASLDetectionPageState();
}

class _ASLDetectionPageState extends State<ASLDetectionPage> {
  File? _selectedImage;
  String? _detectedLetter;
  double? _confidence;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // TODO: Ganti dengan URL API backend teman Anda setelah jadi
  // Contoh: 'http://192.168.1.5:5000/predict'
  final String apiUrl = ''; // Kosongkan dulu untuk testing UI

  // Fungsi untuk ambil foto dari kamera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detectedLetter = null;
          _confidence = null;
        });
      }
    } catch (e) {
      _showErrorDialog('Error mengambil foto: $e');
    }
  }

  // Fungsi untuk pilih gambar dari galeri
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detectedLetter = null;
          _confidence = null;
        });
      }
    } catch (e) {
      _showErrorDialog('Error memilih gambar: $e');
    }
  }

  // Fungsi untuk deteksi huruf ASL
  Future<void> _detectASL() async {
    if (_selectedImage == null) {
      _showErrorDialog('Pilih gambar terlebih dahulu!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (apiUrl.isEmpty) {
        // DUMMY RESPONSE untuk testing UI
        // Hapus bagian ini setelah API backend ready
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _detectedLetter = 'A';
          _confidence = 0.95;
          _isLoading = false;
        });
        return;
      }

      // KODE UNTUK KIRIM KE API BACKEND
      // Uncomment bagian ini setelah API ready
      /*
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (jsonResponse['success'] == true) {
        setState(() {
          _detectedLetter = jsonResponse['letter'];
          _confidence = jsonResponse['confidence'];
          _isLoading = false;
        });
      } else {
        throw Exception(jsonResponse['error'] ?? 'Deteksi gagal');
      }
      */
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error deteksi: $e');
    }
  }

  // Fungsi untuk reset
  void _reset() {
    setState(() {
      _selectedImage = null;
      _detectedLetter = null;
      _confidence = null;
    });
  }

  // Fungsi untuk menampilkan error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASL Alphabet Detection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview Gambar
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
                )
                    : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 80, color: Colors.grey),
                      SizedBox(height: 10),
                      Text(
                        'Belum ada gambar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Tombol Ambil Foto
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Ambil Foto'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 15),

              // Tombol Pilih dari Galeri
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pilih dari Galeri'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 30),

              // Tombol Deteksi
              ElevatedButton.icon(
                onPressed: (_isLoading || _selectedImage == null)
                    ? null
                    : _detectASL,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Memproses...' : 'Deteksi Huruf ASL'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 30),

              // Hasil Deteksi
              if (_detectedLetter != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Hasil Deteksi:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _detectedLetter!,
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
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
}