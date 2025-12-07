import 'dart:async';
import 'dart:io';
import 'dart:math';

Future<String> detectSignLanguage(File image) async {
  // Simulate processing time
  await Future.delayed(const Duration(seconds: 2));

  const mockResults = ['A', 'B', 'C', 'Hello', 'Thank You'];
  final rnd = Random();
  return mockResults[rnd.nextInt(mockResults.length)];
}
