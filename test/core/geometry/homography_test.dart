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

  test('additional hockey-line features are fitted in rink metres', () {
    final imagePoints = <VideoPoint>[
      const VideoPoint(0, 0),
      const VideoPoint(1, 0),
      const VideoPoint(1, 1),
      const VideoPoint(0, 1),
      const VideoPoint(0.381, 0),
      const VideoPoint(0.381, 1),
      const VideoPoint(0.5, 0.5),
    ];
    final rinkPoints = <RinkPoint>[
      const RinkPoint(0, 0),
      const RinkPoint(60, 0),
      const RinkPoint(60, 30),
      const RinkPoint(0, 30),
      const RinkPoint(22.86, 0),
      const RinkPoint(22.86, 30),
      const RinkPoint(30, 15),
    ];
    final homography = Homography.fromPointPairs(
      imagePoints: imagePoints,
      rinkPoints: rinkPoints,
    );

    final rinkPoint = homography.imageToRink(const VideoPoint(0.75, 0.25));

    expect(rinkPoint.xM, closeTo(45, 1e-8));
    expect(rinkPoint.yM, closeTo(7.5, 1e-8));
    expect(
      homography.rinkRmsError(imagePoints: imagePoints, rinkPoints: rinkPoints),
      lessThan(1e-8),
    );
  });
}
