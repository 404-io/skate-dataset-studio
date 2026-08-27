import '../geometry/homography.dart';
import '../geometry/points.dart';

class HockeyLineDefinition {
  const HockeyLineDefinition({
    required this.id,
    required this.label,
    required this.lengthFraction,
  });

  final String id;
  final String label;

  /// Position along rink length, measured from the far short board.
  final double lengthFraction;
}

class HockeyLineReference {
  const HockeyLineReference({
    required this.id,
    required this.label,
    required this.startM,
    required this.endM,
  });

  final String id;
  final String label;
  final RinkPoint startM;
  final RinkPoint endM;
}

class HockeyLineFeaturePoint {
  const HockeyLineFeaturePoint({
    required this.id,
    required this.label,
    required this.rinkPoint,
  });

  final String id;
  final String label;
  final RinkPoint rinkPoint;
}

const standardHockeyLineDefinitions = [
  HockeyLineDefinition(
    id: 'left-blue',
    label: 'Left blue line',
    lengthFraction: 0.381,
  ),
  HockeyLineDefinition(
    id: 'centre-red',
    label: 'Centre red line',
    lengthFraction: 0.5,
  ),
  HockeyLineDefinition(
    id: 'right-blue',
    label: 'Right blue line',
    lengthFraction: 0.619,
  ),
];

class RinkProfile {
  const RinkProfile({
    required this.id,
    required this.label,
    required this.lengthM,
    required this.widthM,
    this.hockeyLineDefinitions = standardHockeyLineDefinitions,
  });

  final String id;
  final String label;
  final double lengthM;
  final double widthM;
  final List<HockeyLineDefinition> hockeyLineDefinitions;

  List<RinkPoint> get boundaryCorners => [
    const RinkPoint(0, 0),
    RinkPoint(lengthM, 0),
    RinkPoint(lengthM, widthM),
    RinkPoint(0, widthM),
  ];

  List<HockeyLineReference> get hockeyLines => [
    for (final definition in hockeyLineDefinitions)
      HockeyLineReference(
        id: definition.id,
        label: definition.label,
        startM: RinkPoint(lengthM * definition.lengthFraction, 0),
        endM: RinkPoint(lengthM * definition.lengthFraction, widthM),
      ),
  ];

  List<HockeyLineFeaturePoint> get hockeyFeaturePoints => [
    for (final line in hockeyLines) ...[
      HockeyLineFeaturePoint(
        id: '${line.id}-far',
        label: '${line.label} / far board',
        rinkPoint: line.startM,
      ),
      HockeyLineFeaturePoint(
        id: '${line.id}-near',
        label: '${line.label} / near board',
        rinkPoint: line.endM,
      ),
    ],
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

class RinkFeatureObservation {
  const RinkFeatureObservation({
    required this.featureId,
    required this.imagePoint,
    required this.rinkPoint,
  });

  final String featureId;
  final VideoPoint imagePoint;
  final RinkPoint rinkPoint;

  Map<String, Object?> toJson() => {
    'featureId': featureId,
    'imagePoint': imagePoint.toJson(),
    'rinkPoint': rinkPoint.toJson(),
  };

  factory RinkFeatureObservation.fromJson(Map<String, Object?> json) =>
      RinkFeatureObservation(
        featureId: json['featureId']! as String,
        imagePoint: VideoPoint.fromJson(
          Map<String, Object?>.from(json['imagePoint']! as Map),
        ),
        rinkPoint: RinkPoint.fromJson(
          Map<String, Object?>.from(json['rinkPoint']! as Map),
        ),
      );
}

class ManualRinkCalibration {
  const ManualRinkCalibration({
    required this.rinkProfileId,
    required this.imageCorners,
    this.hockeyFeatureObservations = const [],
  });

  final String rinkProfileId;
  final List<VideoPoint> imageCorners;
  final List<RinkFeatureObservation> hockeyFeatureObservations;

  Homography get imageToRink => Homography.fromPointPairs(
    imagePoints: [
      ...imageCorners,
      ...hockeyFeatureObservations.map((observation) => observation.imagePoint),
    ],
    rinkPoints: [
      ...rinkProfileById(rinkProfileId).boundaryCorners,
      ...hockeyFeatureObservations.map((observation) => observation.rinkPoint),
    ],
  );

  Map<String, Object?> toJson() => {
    'rinkProfileId': rinkProfileId,
    'imageCorners': imageCorners.map((point) => point.toJson()).toList(),
    'hockeyFeatureObservations': hockeyFeatureObservations
        .map((observation) => observation.toJson())
        .toList(),
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
        hockeyFeatureObservations:
            List<Object?>.from(json['hockeyFeatureObservations'] as List? ?? [])
                .map(
                  (value) => RinkFeatureObservation.fromJson(
                    Map<String, Object?>.from(value! as Map),
                  ),
                )
                .toList(growable: false),
      );
}
