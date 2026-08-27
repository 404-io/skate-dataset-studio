import 'dart:math' as math;

import '../../../core/geometry/points.dart';

enum Foot { left, right }

enum TravelDirection { forward, backward }

enum EdgeSide { inside, outside }

class SkatingEdge {
  const SkatingEdge({
    required this.foot,
    required this.travel,
    required this.side,
  });

  final Foot foot;
  final TravelDirection travel;
  final EdgeSide side;

  String get notation =>
      (foot == Foot.left ? 'L' : 'R') +
      (travel == TravelDirection.forward ? 'F' : 'B') +
      (side == EdgeSide.inside ? 'I' : 'O');

  Map<String, Object?> toJson() => {
    'foot': foot.name,
    'travel': travel.name,
    'side': side.name,
  };

  factory SkatingEdge.fromJson(Map<String, Object?> json) => SkatingEdge(
    foot: Foot.values.byName(json['foot']! as String),
    travel: TravelDirection.values.byName(json['travel']! as String),
    side: EdgeSide.values.byName(json['side']! as String),
  );
}

sealed class GuidePrimitive {
  const GuidePrimitive({required this.subpathId});

  final String subpathId;

  RinkPoint get startM;
  RinkPoint get endM;

  Map<String, Object?> toJson();

  factory GuidePrimitive.fromJson(Map<String, Object?> json) {
    return switch (json['kind']) {
      'line' => LineGuidePrimitive(
        subpathId: json['subpathId']! as String,
        startM: RinkPoint.fromJson(
          Map<String, Object?>.from(json['startM']! as Map),
        ),
        endM: RinkPoint.fromJson(
          Map<String, Object?>.from(json['endM']! as Map),
        ),
      ),
      'arc' => ArcGuidePrimitive(
        subpathId: json['subpathId']! as String,
        centerM: RinkPoint.fromJson(
          Map<String, Object?>.from(json['centerM']! as Map),
        ),
        radiusM: (json['radiusM']! as num).toDouble(),
        startAngleRad: (json['startAngleRad']! as num).toDouble(),
        sweepAngleRad: (json['sweepAngleRad']! as num).toDouble(),
      ),
      _ => throw FormatException('Unknown guide primitive.'),
    };
  }
}

class LineGuidePrimitive extends GuidePrimitive {
  const LineGuidePrimitive({
    required super.subpathId,
    required this.startM,
    required this.endM,
  });

  @override
  final RinkPoint startM;
  @override
  final RinkPoint endM;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'line',
    'subpathId': subpathId,
    'startM': startM.toJson(),
    'endM': endM.toJson(),
  };
}

class ArcGuidePrimitive extends GuidePrimitive {
  const ArcGuidePrimitive({
    required super.subpathId,
    required this.centerM,
    required this.radiusM,
    required this.startAngleRad,
    required this.sweepAngleRad,
  });

  final RinkPoint centerM;
  final double radiusM;
  final double startAngleRad;
  final double sweepAngleRad;

  @override
  RinkPoint get startM => _pointAt(0);

  @override
  RinkPoint get endM => _pointAt(1);

  RinkPoint _pointAt(double fraction) {
    final angle = startAngleRad + sweepAngleRad * fraction;
    return RinkPoint(
      centerM.xM + math.cos(angle) * radiusM,
      centerM.yM + math.sin(angle) * radiusM,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': 'arc',
    'subpathId': subpathId,
    'centerM': centerM.toJson(),
    'radiusM': radiusM,
    'startAngleRad': startAngleRad,
    'sweepAngleRad': sweepAngleRad,
  };
}

class TaskSegment {
  const TaskSegment({
    required this.id,
    required this.primitiveIndex,
    required this.expectedEdge,
  });

  final String id;
  final int primitiveIndex;
  final SkatingEdge expectedEdge;

  Map<String, Object?> toJson() => {
    'id': id,
    'primitiveIndex': primitiveIndex,
    'expectedEdge': expectedEdge.toJson(),
  };

  factory TaskSegment.fromJson(Map<String, Object?> json) => TaskSegment(
    id: json['id']! as String,
    primitiveIndex: json['primitiveIndex']! as int,
    expectedEdge: SkatingEdge.fromJson(
      Map<String, Object?>.from(json['expectedEdge']! as Map),
    ),
  );
}

class TaskDefinition {
  const TaskDefinition({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.footChangeGapM,
    required this.primitives,
    required this.segments,
  });

  final String id;
  final String title;
  final int createdAtMs;
  final double footChangeGapM;
  final List<GuidePrimitive> primitives;
  final List<TaskSegment> segments;

  List<String> validate() {
    if (primitives.length != segments.length) {
      return const [
        'Every path primitive must have one expected edge segment.',
      ];
    }
    final issues = <String>[];
    for (var index = 1; index < segments.length; index++) {
      final previous = segments[index - 1];
      final next = segments[index];
      if (previous.expectedEdge.foot == next.expectedEdge.foot) {
        continue;
      }
      final distance = primitives[index - 1].endM.distanceTo(
        primitives[index].startM,
      );
      if (primitives[index - 1].subpathId == primitives[index].subpathId) {
        issues.add('Foot change ${next.id} must begin a separate subpath.');
      }
      if (distance + 1e-9 < footChangeGapM) {
        issues.add(
          'Foot change ${next.id} does not have the required physical gap.',
        );
      }
    }
    return issues;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAtMs': createdAtMs,
    'footChangeGapM': footChangeGapM,
    'primitives': primitives.map((primitive) => primitive.toJson()).toList(),
    'segments': segments.map((segment) => segment.toJson()).toList(),
  };

  factory TaskDefinition.fromJson(Map<String, Object?> json) => TaskDefinition(
    id: json['id']! as String,
    title: json['title']! as String,
    createdAtMs: json['createdAtMs']! as int,
    footChangeGapM: (json['footChangeGapM']! as num).toDouble(),
    primitives: List<Object?>.from(json['primitives']! as List)
        .map(
          (value) =>
              GuidePrimitive.fromJson(Map<String, Object?>.from(value! as Map)),
        )
        .toList(growable: false),
    segments: List<Object?>.from(json['segments']! as List)
        .map(
          (value) =>
              TaskSegment.fromJson(Map<String, Object?>.from(value! as Map)),
        )
        .toList(growable: false),
  );
}
