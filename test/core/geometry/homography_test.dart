import 'package:flutter_test/flutter_test.dart';
import 'package:skate_dataset_studio/core/geometry/homography.dart';
import 'package:skate_dataset_studio/core/geometry/points.dart';

void main() {
  test('four-corner calibration maps source corners to rink metres', () {
    final homography = Homography.fromFourPointPairs(
      imagePoints: const [
        VideoPoint(0, 0),
        VideoPoint(1, 0),
        VideoPoint(1, 1),
        VideoPoint(0, 1),
      ],
      rinkPoints: const [
        RinkPoint(0, 0),
        RinkPoint(60, 0),
        RinkPoint(60, 30),
        RinkPoint(0, 30),
      ],
    );

    final centre = homography.imageToRink(const VideoPoint(0.5, 0.5));

    expect(centre.xM, closeTo(30, 1e-8));
    expect(centre.yM, closeTo(15, 1e-8));
  });
}
