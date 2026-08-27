import 'dart:math' as math;

/// Normalized coordinates in a source video. They are audit evidence only;
/// all comparison and guide geometry is expressed in rink metres.
class VideoPoint {
  const VideoPoint(this.u, this.v);

  final double u;
  final double v;

  Map<String, Object?> toJson() => {'u': u, 'v': v};

  factory VideoPoint.fromJson(Map<String, Object?> json) =>
      VideoPoint((json['u'] as num).toDouble(), (json['v'] as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is VideoPoint && other.u == u && other.v == v;

  @override
  int get hashCode => Object.hash(u, v);
}

/// A position on the rink floor in metres. This is the canonical shared
/// coordinate system for guides, captures, AR anchors, and VR replay.
class RinkPoint {
  const RinkPoint(this.xM, this.yM);

  final double xM;
  final double yM;

  double distanceTo(RinkPoint other) =>
      math.sqrt(math.pow(other.xM - xM, 2) + math.pow(other.yM - yM, 2));

  Map<String, Object?> toJson() => {'xM': xM, 'yM': yM};

  factory RinkPoint.fromJson(Map<String, Object?> json) =>
      RinkPoint((json['xM'] as num).toDouble(), (json['yM'] as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is RinkPoint && other.xM == xM && other.yM == yM;

  @override
  int get hashCode => Object.hash(xM, yM);
}
