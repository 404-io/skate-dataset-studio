import '../geometry/homography.dart';
import '../geometry/points.dart';

class RinkProfile {
  const RinkProfile({
    required this.id,
    required this.label,
    required this.lengthM,
    required this.widthM,
  });

  final String id;
  final String label;
  final double lengthM;
  final double widthM;

  List<RinkPoint> get boundaryCorners => [
    const RinkPoint(0, 0),
    RinkPoint(lengthM, 0),
    RinkPoint(lengthM, widthM),
    RinkPoint(0, widthM),
  ];
}

/// A new app-local profile list. It does not import or depend on a legacy task
/// catalogue. Facilities may add their own measured profile later.
const rinkProfiles = [
  RinkProfile(
    id: 'training-60x30',
    label: 'Training rink 60 × 30 m',
    lengthM: 60,
    widthM: 30,
  ),
  RinkProfile(
    id: 'training-60x26',
    label: 'Training rink 60 × 26 m',
    lengthM: 60,
    widthM: 26,
  ),
];

RinkProfile rinkProfileById(String id) =>
    rinkProfiles.firstWhere((profile) => profile.id == id);

class ManualRinkCalibration {
  const ManualRinkCalibration({
    required this.rinkProfileId,
    required this.imageCorners,
  });

  final String rinkProfileId;
  final List<VideoPoint> imageCorners;

  Homography get imageToRink => Homography.fromFourPointPairs(
    imagePoints: imageCorners,
    rinkPoints: rinkProfileById(rinkProfileId).boundaryCorners,
  );

  Map<String, Object?> toJson() => {
    'rinkProfileId': rinkProfileId,
    'imageCorners': imageCorners.map((point) => point.toJson()).toList(),
  };

  factory ManualRinkCalibration.fromJson(Map<String, Object?> json) =>
      ManualRinkCalibration(
        rinkProfileId: json['rinkProfileId']! as String,
        imageCorners: List<Object?>.from(json['imageCorners']! as List)
            .map(
              (value) =>
                  VideoPoint.fromJson(Map<String, Object?>.from(value! as Map)),
            )
            .toList(growable: false),
      );
}
