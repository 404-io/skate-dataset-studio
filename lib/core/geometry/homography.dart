import 'dart:math' as math;

import 'points.dart';

const _epsilon = 1e-8;

/// Projective mapping from normalized video coordinates to rink-floor metres.
/// Four non-collinear correspondences solve the eight free matrix values;
/// extra points are fitted with least squares.
class Homography {
  const Homography._(this._values);

  final List<double> _values;

  List<double> get values => List.unmodifiable(_values);

  factory Homography.fromFourPointPairs({
    required List<VideoPoint> imagePoints,
    required List<RinkPoint> rinkPoints,
  }) {
    if (imagePoints.length != 4 || rinkPoints.length != 4) {
      throw ArgumentError(
        'A homography needs exactly four corresponding points.',
      );
    }
    final matrix = <List<double>>[];
    final target = <double>[];
    for (var index = 0; index < 4; index++) {
      final source = imagePoints[index];
      final destination = rinkPoints[index];
      matrix.add([
        source.u,
        source.v,
        1,
        0,
        0,
        0,
        -source.u * destination.xM,
        -source.v * destination.xM,
      ]);
      target.add(destination.xM);
      matrix.add([
        0,
        0,
        0,
        source.u,
        source.v,
        1,
        -source.u * destination.yM,
        -source.v * destination.yM,
      ]);
      target.add(destination.yM);
    }
    return Homography._([..._solve(matrix, target), 1]);
  }

  /// Fits a homography to four or more correspondence pairs.
  ///
  /// Four corner taps set the plane. Optional hockey-line features make the
  /// system over-determined, so tapping noise is distributed by least squares.
  factory Homography.fromPointPairs({
    required List<VideoPoint> imagePoints,
    required List<RinkPoint> rinkPoints,
  }) {
    if (imagePoints.length != rinkPoints.length || imagePoints.length < 4) {
      throw ArgumentError(
        'A homography needs at least four corresponding point pairs.',
      );
    }
    if (imagePoints.length == 4) {
      return Homography.fromFourPointPairs(
        imagePoints: imagePoints,
        rinkPoints: rinkPoints,
      );
    }

    final matrix = <List<double>>[];
    final target = <double>[];
    for (var index = 0; index < imagePoints.length; index++) {
      final source = imagePoints[index];
      final destination = rinkPoints[index];
      matrix.add([
        source.u,
        source.v,
        1,
        0,
        0,
        0,
        -source.u * destination.xM,
        -source.v * destination.xM,
      ]);
      target.add(destination.xM);
      matrix.add([
        0,
        0,
        0,
        source.u,
        source.v,
        1,
        -source.u * destination.yM,
        -source.v * destination.yM,
      ]);
      target.add(destination.yM);
    }

    final normalMatrix = List<List<double>>.generate(
      8,
      (row) => List<double>.generate(8, (column) {
        var total = 0.0;
        for (final equation in matrix) {
          total += equation[row] * equation[column];
        }
        return total;
      }),
    );
    final normalTarget = List<double>.generate(8, (column) {
      var total = 0.0;
      for (var row = 0; row < matrix.length; row++) {
        total += matrix[row][column] * target[row];
      }
      return total;
    });
    return Homography._([..._solve(normalMatrix, normalTarget), 1]);
  }

  RinkPoint imageToRink(VideoPoint point) {
    final projected = _project(point.u, point.v);
    return RinkPoint(projected.$1, projected.$2);
  }

  VideoPoint rinkToImage(RinkPoint point) {
    final projected = inverse()._project(point.xM, point.yM);
    return VideoPoint(projected.$1, projected.$2);
  }

  /// Root-mean-square rink-plane error in metres for correspondence pairs.
  double rinkRmsError({
    required List<VideoPoint> imagePoints,
    required List<RinkPoint> rinkPoints,
  }) {
    if (imagePoints.length != rinkPoints.length || imagePoints.isEmpty) {
      throw ArgumentError('Error measurement needs equally sized point pairs.');
    }
    var squaredError = 0.0;
    for (var index = 0; index < imagePoints.length; index++) {
      final projected = imageToRink(imagePoints[index]);
      final dx = projected.xM - rinkPoints[index].xM;
      final dy = projected.yM - rinkPoints[index].yM;
      squaredError += dx * dx + dy * dy;
    }
    return math.sqrt(squaredError / imagePoints.length);
  }

  Homography inverse() {
    final a = _values[0];
    final b = _values[1];
    final c = _values[2];
    final d = _values[3];
    final e = _values[4];
    final f = _values[5];
    final g = _values[6];
    final h = _values[7];
    final i = _values[8];
    final determinant =
        a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (determinant.abs() < _epsilon) {
      throw StateError(
        'The calibration is singular. Choose four wider points.',
      );
    }
    return Homography._([
      (e * i - f * h) / determinant,
      (c * h - b * i) / determinant,
      (b * f - c * e) / determinant,
      (f * g - d * i) / determinant,
      (a * i - c * g) / determinant,
      (c * d - a * f) / determinant,
      (d * h - e * g) / determinant,
      (b * g - a * h) / determinant,
      (a * e - b * d) / determinant,
    ]);
  }

  (double, double) _project(double x, double y) {
    final denominator = _values[6] * x + _values[7] * y + _values[8];
    if (denominator.abs() < _epsilon) {
      throw StateError('The point lies on the calibration horizon.');
    }
    return (
      (_values[0] * x + _values[1] * y + _values[2]) / denominator,
      (_values[3] * x + _values[4] * y + _values[5]) / denominator,
    );
  }
}

List<double> _solve(List<List<double>> matrix, List<double> target) {
  final size = target.length;
  final augmented = List<List<double>>.generate(
    size,
    (row) => [...matrix[row], target[row]],
  );
  for (var column = 0; column < size; column++) {
    var pivot = column;
    for (var row = column + 1; row < size; row++) {
      if (augmented[row][column].abs() > augmented[pivot][column].abs()) {
        pivot = row;
      }
    }
    if (augmented[pivot][column].abs() < _epsilon) {
      throw ArgumentError('The selected calibration points are degenerate.');
    }
    final previous = augmented[column];
    augmented[column] = augmented[pivot];
    augmented[pivot] = previous;

    final divisor = augmented[column][column];
    for (var index = column; index <= size; index++) {
      augmented[column][index] /= divisor;
    }
    for (var row = 0; row < size; row++) {
      if (row == column) {
        continue;
      }
      final factor = augmented[row][column];
      for (var index = column; index <= size; index++) {
        augmented[row][index] -= factor * augmented[column][index];
      }
    }
  }
  return augmented.map((row) => row[size]).toList(growable: false);
}
