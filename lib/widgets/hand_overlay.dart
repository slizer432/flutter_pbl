import 'package:flutter/material.dart';

/// Hand landmark connections for MediaPipe hand skeleton.
///
/// MediaPipe Hand Landmark Model:
/// 0: WRIST
/// 1-4: THUMB (CMC, MCP, IP, TIP)
/// 5-8: INDEX FINGER (MCP, PIP, DIP, TIP)
/// 9-12: MIDDLE FINGER (MCP, PIP, DIP, TIP)
/// 13-16: RING FINGER (MCP, PIP, DIP, TIP)
/// 17-20: PINKY (MCP, PIP, DIP, TIP)
class HandConnections {
  /// Thumb connections: wrist -> cmc -> mcp -> ip -> tip
  static const thumb = [(0, 1), (1, 2), (2, 3), (3, 4)];

  /// Index finger connections
  static const index = [(0, 5), (5, 6), (6, 7), (7, 8)];

  /// Middle finger connections
  static const middle = [(0, 9), (9, 10), (10, 11), (11, 12)];

  /// Ring finger connections
  static const ring = [(0, 13), (13, 14), (14, 15), (15, 16)];

  /// Pinky finger connections
  static const pinky = [(0, 17), (17, 18), (18, 19), (19, 20)];

  /// Palm connections (between finger bases)
  static const palm = [(5, 9), (9, 13), (13, 17)];

  /// All connections combined
  static const all = [
    ...thumb,
    ...index,
    ...middle,
    ...ring,
    ...pinky,
    ...palm,
  ];
}

/// Represents a single hand landmark point.
class LandmarkPoint {
  final double x; // Normalized x coordinate (0-1)
  final double y; // Normalized y coordinate (0-1)
  final double z; // Depth (relative to wrist)

  const LandmarkPoint({
    required this.x,
    required this.y,
    required this.z,
  });

  /// Convert normalized coordinates to screen coordinates.
  /// Coordinates should already be transformed for display orientation.
  ///
  /// [size] - The size of the canvas/preview
  /// [mirrorX] - Whether to flip horizontally (for front camera)
  /// [rotation] - Rotation in degrees (0, 90, 180, 270) - usually 0 if pre-transformed
  Offset toScreen(
    Size size, {
    bool mirrorX = false,
    int rotation = 0,
  }) {
    double screenX = x;
    double screenY = y;

    // Apply rotation (usually not needed if coordinates are pre-transformed)
    switch (rotation) {
      case 90:
        final temp = screenX;
        screenX = 1.0 - screenY;
        screenY = temp;
        break;
      case 180:
        screenX = 1.0 - screenX;
        screenY = 1.0 - screenY;
        break;
      case 270:
        final temp = screenX;
        screenX = screenY;
        screenY = 1.0 - temp;
        break;
    }

    // Mirror if needed
    if (mirrorX) {
      screenX = 1.0 - screenX;
    }

    return Offset(screenX * size.width, screenY * size.height);
  }
}

/// CustomPainter for drawing hand landmark overlay.
class HandOverlayPainter extends CustomPainter {
  /// List of 21 hand landmarks (or null if no hand detected)
  final List<LandmarkPoint>? landmarks;

  /// Whether to mirror X coordinates (for front camera)
  final bool mirrorX;

  /// Sensor rotation in degrees
  final int sensorRotation;

  /// Colors for different parts
  final Color thumbColor;
  final Color indexColor;
  final Color middleColor;
  final Color ringColor;
  final Color pinkyColor;
  final Color palmColor;
  final Color pointColor;

  /// Sizes
  final double pointRadius;
  final double lineWidth;

  /// Whether to show landmark indices (for debugging)
  final bool showIndices;

  HandOverlayPainter({
    this.landmarks,
    this.mirrorX = true,
    this.sensorRotation = 0,
    this.thumbColor = const Color(0xFFFF6B6B),
    this.indexColor = const Color(0xFF4ECDC4),
    this.middleColor = const Color(0xFFFFE66D),
    this.ringColor = const Color(0xFF95E1D3),
    this.pinkyColor = const Color(0xFFDDA0DD),
    this.palmColor = const Color(0xFF98D8C8),
    this.pointColor = Colors.white,
    this.pointRadius = 6.0,
    this.lineWidth = 3.0,
    this.showIndices = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.length != 21) {
      return;
    }

    // Convert all landmarks to screen coordinates
    final points = landmarks!
        .map((lm) => lm.toScreen(
              size,
              mirrorX: mirrorX,
              rotation: sensorRotation,
            ))
        .toList();

    // Draw connections (skeleton lines)
    _drawConnections(
      canvas,
      points,
      HandConnections.thumb,
      _createLinePaint(thumbColor),
    );
    _drawConnections(
      canvas,
      points,
      HandConnections.index,
      _createLinePaint(indexColor),
    );
    _drawConnections(
      canvas,
      points,
      HandConnections.middle,
      _createLinePaint(middleColor),
    );
    _drawConnections(
      canvas,
      points,
      HandConnections.ring,
      _createLinePaint(ringColor),
    );
    _drawConnections(
      canvas,
      points,
      HandConnections.pinky,
      _createLinePaint(pinkyColor),
    );
    _drawConnections(
      canvas,
      points,
      HandConnections.palm,
      _createLinePaint(palmColor),
    );

    // Draw landmark points
    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];

      // Draw colored point based on finger
      final color = _getPointColor(i);
      canvas.drawCircle(
        point,
        pointRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // Draw border
      canvas.drawCircle(point, pointRadius, borderPaint);

      // Draw index number if enabled (for debugging)
      if (showIndices) {
        _drawText(canvas, point, i.toString());
      }
    }
  }

  Paint _createLinePaint(Color color) {
    return Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
  }

  void _drawConnections(
    Canvas canvas,
    List<Offset> points,
    List<(int, int)> connections,
    Paint paint,
  ) {
    for (final (start, end) in connections) {
      if (start < points.length && end < points.length) {
        canvas.drawLine(points[start], points[end], paint);
      }
    }
  }

  Color _getPointColor(int index) {
    if (index == 0) return palmColor; // Wrist
    if (index <= 4) return thumbColor;
    if (index <= 8) return indexColor;
    if (index <= 12) return middleColor;
    if (index <= 16) return ringColor;
    return pinkyColor;
  }

  void _drawText(Canvas canvas, Offset position, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black,
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height + 8),
    );
  }

  @override
  bool shouldRepaint(covariant HandOverlayPainter oldDelegate) {
    return landmarks != oldDelegate.landmarks ||
        mirrorX != oldDelegate.mirrorX ||
        sensorRotation != oldDelegate.sensorRotation;
  }
}

/// Widget wrapper for hand overlay.
class HandOverlay extends StatelessWidget {
  final List<LandmarkPoint>? landmarks;
  final bool mirrorX;
  final int sensorRotation;
  final bool showIndices;

  const HandOverlay({
    super.key,
    this.landmarks,
    this.mirrorX = true,
    this.sensorRotation = 0,
    this.showIndices = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HandOverlayPainter(
        landmarks: landmarks,
        mirrorX: mirrorX,
        sensorRotation: sensorRotation,
        showIndices: showIndices,
      ),
      size: Size.infinite,
    );
  }
}
