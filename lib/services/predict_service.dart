import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service for calling the Python prediction server.
///
/// Server Setup Instructions:
/// --------------------------
/// 1. Navigate to server directory: cd server
/// 2. Install dependencies: pip install -r requirements.txt
/// 3. Place model files in server/:
///    - linear_svm_model.pkl
///    - label_encoder.pkl
/// 4. Run: uvicorn app:app --host 0.0.0.0 --port 8000
///
/// For Android emulator: use 10.0.2.2:8000
/// For physical device: use your PC's IP address (e.g., 192.168.1.100:8000)
class PredictService {
  /// Base URL for the prediction server.
  /// Change this to your server's address:
  /// - Android Emulator: http://10.0.2.2:8000
  /// - Physical Device: http://<YOUR_PC_IP>:8000
  /// - Same device: http://localhost:8000
  static const String _baseUrl = 'http://10.29.57.179:8000';

  /// Timeout for HTTP requests
  static const Duration _timeout = Duration(seconds: 5);

  /// Singleton instance
  static final PredictService _instance = PredictService._internal();
  factory PredictService() => _instance;
  PredictService._internal();

  /// Check if the server is reachable and models are loaded.
  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['model_loaded'] == true &&
            data['label_encoder_loaded'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Predict the sign language letter from hand landmark features.
  ///
  /// [features] should be a list of 63 doubles representing
  /// [x1, y1, z1, x2, y2, z2, ..., x21, y21, z21].
  ///
  /// Returns a [PredictionResult] with the predicted letter and optional confidence.
  /// Returns null if prediction fails.
  Future<PredictionResult?> predict(List<double> features) async {
    if (features.length != 63) {
      throw ArgumentError('Expected 63 features, got ${features.length}');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'features': features}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PredictionResult(
          prediction: data['prediction'] as String,
          confidence: data['confidence'] as double?,
        );
      } else {
        // Log error for debugging
        // ignore: avoid_print
        print('Prediction failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Prediction error: $e');
      return null;
    }
  }

  /// Update the server base URL at runtime.
  /// Useful for configuration screens.
  static String get baseUrl => _baseUrl;
}

/// Result of a prediction request.
class PredictionResult {
  final String prediction;
  final double? confidence;

  const PredictionResult({
    required this.prediction,
    this.confidence,
  });

  @override
  String toString() {
    if (confidence != null) {
      return '$prediction (${(confidence! * 100).toStringAsFixed(1)}%)';
    }
    return prediction;
  }
}
