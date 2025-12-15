import 'dart:convert';

/// Represents a single prediction item for history.
class PredictionItem {
  final String letter;
  final DateTime timestamp;
  final double? confidence;

  const PredictionItem({
    required this.letter,
    required this.timestamp,
    this.confidence,
  });

  /// Create from JSON map.
  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      letter: json['letter'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      confidence: json['confidence'] as double?,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'letter': letter,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
    };
  }

  /// Create a list from JSON string.
  static List<PredictionItem> listFromJsonString(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((e) => PredictionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Convert list to JSON string.
  static String listToJsonString(List<PredictionItem> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  @override
  String toString() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    if (confidence != null) {
      return '$letter (${(confidence! * 100).toStringAsFixed(0)}%) at $time';
    }
    return '$letter at $time';
  }
}
