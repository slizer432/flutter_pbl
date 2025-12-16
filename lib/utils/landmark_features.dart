/// Utility class for extracting features from hand landmarks.
///
/// Converts raw hand landmark data into a feature vector suitable
/// for machine learning prediction.
class LandmarkFeatures {
  /// Number of landmarks in MediaPipe hand model
  static const int numLandmarks = 21;

  /// Number of coordinates per landmark (x, y, z)
  static const int coordsPerLandmark = 3;

  /// Total number of features (21 * 3 = 63)
  static const int totalFeatures = numLandmarks * coordsPerLandmark;

  /// Convert hand landmarks to a flat feature vector.
  ///
  /// Input: List of 21 landmarks, each with (x, y, z) coordinates.
  /// Output: List of 63 doubles [x1, y1, z1, x2, y2, z2, ..., x21, y21, z21]
  ///
  /// Coordinates are expected to be normalized (0.0 to 1.0 for x, y).
  static List<double> landmarksToFeatures(
    List<({double x, double y, double z})> landmarks,
  ) {
    if (landmarks.length != numLandmarks) {
      throw ArgumentError(
        'Expected $numLandmarks landmarks, got ${landmarks.length}',
      );
    }

    final features = <double>[];
    for (final lm in landmarks) {
      features.add(lm.x);
      features.add(lm.y);
      features.add(lm.z);
    }
    return features;
  }

  /// Convert from separate coordinate lists to feature vector.
  ///
  /// Alternative method when landmarks come as separate x, y, z arrays.
  static List<double> fromCoordinateLists(
    List<double> xCoords,
    List<double> yCoords,
    List<double> zCoords,
  ) {
    if (xCoords.length != numLandmarks ||
        yCoords.length != numLandmarks ||
        zCoords.length != numLandmarks) {
      throw ArgumentError('Each coordinate list must have $numLandmarks values');
    }

    final features = <double>[];
    for (var i = 0; i < numLandmarks; i++) {
      features.add(xCoords[i]);
      features.add(yCoords[i]);
      features.add(zCoords[i]);
    }
    return features;
  }

  /// Normalize landmarks relative to wrist position.
  ///
  /// This can improve prediction consistency by making features
  /// invariant to hand position in the frame.
  static List<double> normalizedToWrist(
    List<({double x, double y, double z})> landmarks,
  ) {
    if (landmarks.length != numLandmarks) {
      throw ArgumentError(
        'Expected $numLandmarks landmarks, got ${landmarks.length}',
      );
    }

    // Use wrist (landmark 0) as origin
    final wrist = landmarks[0];

    final features = <double>[];
    for (final lm in landmarks) {
      features.add(lm.x - wrist.x);
      features.add(lm.y - wrist.y);
      features.add(lm.z - wrist.z);
    }
    return features;
  }

  /// Calculate distances between key landmarks.
  ///
  /// This provides a more robust feature set that's invariant to
  /// rotation and scale. Returns distances between fingertips and
  /// palm landmarks.
  static List<double> landmarkDistances(
    List<({double x, double y, double z})> landmarks,
  ) {
    if (landmarks.length != numLandmarks) {
      throw ArgumentError(
        'Expected $numLandmarks landmarks, got ${landmarks.length}',
      );
    }

    // Key landmark indices
    const wrist = 0;
    const thumbTip = 4;
    const indexTip = 8;
    const middleTip = 12;
    const ringTip = 16;
    const pinkyTip = 20;
    const indexMcp = 5;
    const pinkyMcp = 17;

    final tips = [thumbTip, indexTip, middleTip, ringTip, pinkyTip];
    final features = <double>[];

    // Distance from each fingertip to wrist
    for (final tip in tips) {
      features.add(_distance(landmarks[tip], landmarks[wrist]));
    }

    // Distance from each fingertip to palm center (approximate)
    final palmCenterX =
        (landmarks[0].x + landmarks[indexMcp].x + landmarks[pinkyMcp].x) / 3;
    final palmCenterY =
        (landmarks[0].y + landmarks[indexMcp].y + landmarks[pinkyMcp].y) / 3;
    final palmCenterZ =
        (landmarks[0].z + landmarks[indexMcp].z + landmarks[pinkyMcp].z) / 3;
    final palmCenter = (x: palmCenterX, y: palmCenterY, z: palmCenterZ);

    for (final tip in tips) {
      features.add(_distance(landmarks[tip], palmCenter));
    }

    // Inter-fingertip distances
    for (var i = 0; i < tips.length; i++) {
      for (var j = i + 1; j < tips.length; j++) {
        features.add(_distance(landmarks[tips[i]], landmarks[tips[j]]));
      }
    }

    return features;
  }

  /// Calculate Euclidean distance between two 3D points.
  static double _distance(
    ({double x, double y, double z}) a,
    ({double x, double y, double z}) b,
  ) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return (dx * dx + dy * dy + dz * dz).sqrt();
  }
}

/// Extension for sqrt on double
extension DoubleExt on double {
  double sqrt() => this >= 0 ? this.toDouble().sqrtImpl() : double.nan;
  double sqrtImpl() {
    if (this == 0) return 0;
    var x = this;
    var y = (x + 1) / 2;
    while (y < x) {
      x = y;
      y = (x + this / x) / 2;
    }
    return x;
  }
}
