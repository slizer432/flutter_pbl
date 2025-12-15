import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

// TODO: Ganti dengan IP laptop teman saat WiFi sama
// Contoh: 'http://192.168.1.105:5000/predict'
const String API_URL = 'http://192.168.1.105:5000/predict';  // GANTI INI NANTI!

Future<String> detectSignLanguage(File image) async {
  try {
    print('Sending image to: $API_URL');

    // 1. Buat multipart request
    var request = http.MultipartRequest('POST', Uri.parse(API_URL));

    // 2. Attach file gambar (key: "image" sesuai backend)
    request.files.add(
      await http.MultipartFile.fromPath('image', image.path),
    );

    // 3. Kirim request dengan timeout
    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Request timeout - Server tidak merespon');
      },
    );

    // 4. Baca response
    var response = await http.Response.fromStream(streamedResponse);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    // 5. Cek status code
    if (response.statusCode == 200) {
      // Parse JSON response
      var jsonResponse = json.decode(response.body);

      if (jsonResponse['success'] == true) {
        // Return huruf yang terdeteksi
        String letter = jsonResponse['letter'];
        double confidence = jsonResponse['confidence'] ?? 1.0;

        print('Detected: $letter (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');

        return letter;
      } else {
        throw Exception(jsonResponse['error'] ?? 'Deteksi gagal');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }

  } on SocketException {
    throw Exception('Tidak bisa connect ke server\n'
        'Pastikan:\n'
        '1. Backend sudah jalan (python app.py)\n'
        '2. HP dan laptop satu WiFi\n'
        '3. IP address benar');
  } on TimeoutException {
    throw Exception('Request timeout - Server terlalu lama merespon');
  } catch (e) {
    print('Error: $e');
    throw Exception('Error: $e');
  }
}

// Fungsi untuk test koneksi ke backend (OPSIONAL)
Future<Map<String, dynamic>> testConnection() async {
  try {
    final healthUrl = API_URL.replaceAll('/predict', '/health');
    print('Testing connection to: $healthUrl');

    var response = await http.get(Uri.parse(healthUrl)).timeout(
      const Duration(seconds: 5),
    );

    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      print('Connection test successful: ${json['message']}');
      return {
        'connected': true,
        'message': json['message'],
        'model_info': json['model_info']
      };
    }
    return {'connected': false, 'message': 'Server not responding'};
  } catch (e) {
    print('Connection test failed: $e');
    return {'connected': false, 'message': 'Error: $e'};
  }
}