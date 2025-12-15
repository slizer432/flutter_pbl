import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prediction_item.dart';
import '../services/predict_service.dart';
import '../widgets/hand_overlay.dart';

/// Real-time hand detection screen with landmark overlay and prediction.
///
/// Features:
/// - Live camera preview
/// - Hand landmark detection using MediaPipe
/// - Skeleton overlay drawing
/// - Letter prediction via Python server
/// - Auto-save predictions every 3 seconds
/// - Persistent history using SharedPreferences
class RealtimeDetectionScreen extends StatefulWidget {
  const RealtimeDetectionScreen({super.key});

  @override
  State<RealtimeDetectionScreen> createState() =>
      _RealtimeDetectionScreenState();
}

class _RealtimeDetectionScreenState extends State<RealtimeDetectionScreen>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;

  // Hand landmarker
  HandLandmarkerPlugin? _handLandmarker;

  // Detection state
  List<LandmarkPoint>? _currentLandmarks;
  String _currentPrediction = '';
  double? _currentConfidence;
  bool _isDetecting = false;
  bool _isDetectionRunning = false;

  // Auto-save timer (3 seconds)
  Timer? _autoSaveTimer;
  String _lastSavedLetter = '';
  static const Duration _saveInterval = Duration(seconds: 3);

  // Prediction history
  List<PredictionItem> _predictionHistory = [];
  static const String _historyKey = 'prediction_history';

  // Server status
  bool _isServerConnected = false;
  final PredictService _predictService = PredictService();

  // Error state
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDetection();
    _autoSaveTimer?.cancel();
    _cameraController?.dispose();
    _handLandmarker?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeAll() async {
    await _loadHistory();
    await _checkServerConnection();
    await _initializeCamera();
    _initializeHandLandmarker();
  }

  Future<void> _checkServerConnection() async {
    final connected = await _predictService.healthCheck();
    if (mounted) {
      setState(() {
        _isServerConnected = connected;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras available');
        return;
      }

      // Prefer front camera
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera initialization failed: $e');
      }
    }
  }

  void _initializeHandLandmarker() {
    try {
      _handLandmarker = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.5,
        delegate: HandLandmarkerDelegate.gpu,
      );
    } catch (e) {
      // Fallback to CPU
      try {
        _handLandmarker = HandLandmarkerPlugin.create(
          numHands: 1,
          minHandDetectionConfidence: 0.5,
          delegate: HandLandmarkerDelegate.cpu,
        );
      } catch (e2) {
        if (mounted) {
          setState(() => _errorMessage = 'Hand landmarker failed: $e2');
        }
      }
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey) ?? '';
    if (mounted) {
      setState(() {
        _predictionHistory = PredictionItem.listFromJsonString(historyJson);
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      PredictionItem.listToJsonString(_predictionHistory),
    );
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) {
      setState(() {
        _predictionHistory = [];
        _lastSavedLetter = '';
      });
    }
  }

  void _startDetection() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _handLandmarker == null) {
      return;
    }

    setState(() => _isDetectionRunning = true);

    // Start camera image stream
    _cameraController!.startImageStream(_processFrame);

    // Start auto-save timer
    _autoSaveTimer = Timer.periodic(_saveInterval, (_) => _autoSavePrediction());
  }

  void _stopDetection() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }

    if (mounted) {
      setState(() {
        _isDetectionRunning = false;
        _currentLandmarks = null;
        _currentPrediction = '';
        _currentConfidence = null;
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDetecting || _handLandmarker == null) return;
    _isDetecting = true;

    try {
      // Detect hand landmarks
      final hands = _handLandmarker!.detect(
        image,
        _cameraController!.description.sensorOrientation,
      );

      if (!mounted) return;

      if (hands.isEmpty) {
        setState(() {
          _currentLandmarks = null;
          _currentPrediction = '';
          _currentConfidence = null;
        });
      } else {
        // Convert to LandmarkPoint list
        final hand = hands.first;
        final landmarks = hand.landmarks
            .map((lm) => LandmarkPoint(x: lm.x, y: lm.y, z: lm.z))
            .toList();

        setState(() => _currentLandmarks = landmarks);

        // Run prediction if server is connected
        if (_isServerConnected) {
          await _runPrediction(hand.landmarks);
        }
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _runPrediction(List<Landmark> landmarks) async {
    // Convert landmarks to feature vector [x1,y1,z1,...,x21,y21,z21]
    final features = <double>[];
    for (final lm in landmarks) {
      features.add(lm.x);
      features.add(lm.y);
      features.add(lm.z);
    }

    // Call prediction server
    final result = await _predictService.predict(features);

    if (mounted && result != null) {
      setState(() {
        _currentPrediction = result.prediction;
        _currentConfidence = result.confidence;
      });
    }
  }

  void _autoSavePrediction() {
    // Only save if:
    // 1. There's a valid prediction
    // 2. It's different from the last saved letter (avoid duplicates)
    // 3. Hand is currently detected
    if (_currentPrediction.isNotEmpty &&
        _currentPrediction != _lastSavedLetter &&
        _currentLandmarks != null) {
      final item = PredictionItem(
        letter: _currentPrediction,
        timestamp: DateTime.now(),
        confidence: _currentConfidence,
      );

      setState(() {
        _predictionHistory.add(item);
        _lastSavedLetter = _currentPrediction;
      });

      _saveHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Real-time Detection'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          // Server status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.cloud,
              color: _isServerConnected ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          // Refresh server connection
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkServerConnection,
            tooltip: 'Check server connection',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview with overlay
            Expanded(flex: 3, child: _buildCameraPreview()),

            // Current prediction display
            _buildPredictionDisplay(),

            // History and controls
            Expanded(flex: 2, child: _buildHistorySection()),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeAll,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (mirrored for front camera)
          Transform.flip(
            flipX: _cameraController!.description.lensDirection ==
                CameraLensDirection.front,
            child: CameraPreview(_cameraController!),
          ),

          // Hand landmark overlay
          if (_currentLandmarks != null)
            HandOverlay(
              landmarks: _currentLandmarks,
              mirrorX: false, // Already mirrored by Transform
              sensorRotation: 0,
            ),

          // Detection status badge
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _currentLandmarks != null
                    ? Colors.green.withValues(alpha: 0.8)
                    : Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentLandmarks != null
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currentLandmarks != null ? 'Hand Detected' : 'No Hand',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Detection running indicator
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isDetectionRunning
                    ? Colors.green.withValues(alpha: 0.8)
                    : Colors.orange.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isDetectionRunning ? 'Running' : 'Stopped',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      color: Colors.black87,
      child: Column(
        children: [
          const Text(
            'Current Prediction',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentPrediction.isNotEmpty
                    ? [Colors.deepPurple, Colors.purple]
                    : [Colors.grey.shade800, Colors.grey.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  _currentPrediction.isNotEmpty ? _currentPrediction : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentConfidence != null && _currentPrediction.isNotEmpty)
                  Text(
                    'Confidence: ${(_currentConfidence! * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                if (!_isServerConnected)
                  const Text(
                    'Server not connected',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prediction History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  // Start/Stop button
                  ElevatedButton.icon(
                    onPressed:
                        _isDetectionRunning ? _stopDetection : _startDetection,
                    icon: Icon(
                      _isDetectionRunning ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(_isDetectionRunning ? 'Stop' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isDetectionRunning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Clear button
                  IconButton(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade400,
                    tooltip: 'Clear history',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Auto-save indicator
          Text(
            'Auto-saves every 3 seconds when hand detected',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // History list
          Expanded(
            child: _predictionHistory.isEmpty
                ? Center(
                    child: Text(
                      'No predictions yet.\nTap Start and show your hand!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    reverse: true, // Show newest at bottom
                    itemCount: _predictionHistory.length,
                    itemBuilder: (context, index) {
                      final item = _predictionHistory[
                          _predictionHistory.length - 1 - index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  item.letter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (item.confidence != null)
                                    Text(
                                      '${(item.confidence! * 100).toStringAsFixed(1)}% confidence',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Collected letters display
          if (_predictionHistory.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text(
                    'Collected: ',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Expanded(
                    child: Text(
                      _predictionHistory.map((e) => e.letter).join(''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
