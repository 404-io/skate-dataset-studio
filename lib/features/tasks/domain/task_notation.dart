import 'dart:math' as math;

import '../../../core/geometry/points.dart';
import 'task_definition.dart';

/// Parses a compact, line-based format for deterministic skating-task guides.
///
/// Each drawable primitive carries its expected skating edge explicitly. This
/// keeps a task guide (what should be skated) separate from a later video
/// observation (what was actually skated).
///
/// ```text
/// task Forward outside eight
/// gap 0.22
/// arc left-loop LFO left-loop 12 8 3 180 -360
/// arc right-loop RFO right-loop 18.22 8 3 0 360
/// ```
///
/// Columns for `arc` are: id, edge, subpath, centre-x-m, centre-y-m,
/// radius-m, start-degrees, sweep-degrees.  Columns for `line` are: id,
/// edge, subpath, start-x-m, start-y-m, end-x-m, end-y-m.
class TaskNotationParser {
  const TaskNotationParser();

  TaskDefinition parse({
    required String source,
    required String id,
    required int createdAtMs,
  }) {
    var title = 'Untitled task';
    var footChangeGapM = 0.22;
    final primitives = <GuidePrimitive>[];
    final segments = <TaskSegment>[];

    final lines = source.split(RegExp(r'\r?\n'));
    for (var index = 0; index < lines.length; index++) {
      final lineNumber = index + 1;
      final clean = lines[index].split('#').first.trim();
      if (clean.isEmpty) {
        continue;
      }
      final parts = clean.split(RegExp(r'\s+'));
      final command = parts.first.toLowerCase();

      if (command == 'task') {
        final parsedTitle = clean.substring(parts.first.length).trim();
        if (parsedTitle.isEmpty) {
          throw TaskNotationFormatException(lineNumber, 'Task title is empty.');
        }
        title = parsedTitle;
        continue;
      }
      if (command == 'gap') {
        if (parts.length != 2) {
          throw TaskNotationFormatException(
            lineNumber,
            'gap requires one value in metres.',
          );
        }
        footChangeGapM = _number(parts[1], lineNumber, 'gap');
        if (footChangeGapM < 0) {
          throw TaskNotationFormatException(
            lineNumber,
            'gap cannot be negative.',
          );
        }
        continue;
      }

      switch (command) {
        case 'line':
          _parseLine(parts, lineNumber, primitives, segments);
          break;
        case 'arc':
          _parseArc(parts, lineNumber, primitives, segments);
          break;
        default:
          throw TaskNotationFormatException(
            lineNumber,
            'Unknown command "$command". Use task, gap, line, or arc.',
          );
      }
    }

    if (primitives.isEmpty) {
      throw const TaskNotationFormatException(
        0,
        'A task needs at least one path.',
      );
    }

    final definition = TaskDefinition(
      id: id,
      title: title,
      createdAtMs: createdAtMs,
      footChangeGapM: footChangeGapM,
      primitives: List.unmodifiable(primitives),
      segments: List.unmodifiable(segments),
    );
    final issues = definition.validate();
    if (issues.isNotEmpty) {
      throw TaskNotationFormatException(0, issues.join(' '));
    }
    return definition;
  }

  void _parseLine(
    List<String> parts,
    int lineNumber,
    List<GuidePrimitive> primitives,
    List<TaskSegment> segments,
  ) {
    if (parts.length != 8) {
      throw TaskNotationFormatException(
        lineNumber,
        'line requires 7 values after the command.',
      );
    }
    final edge = _edge(parts[2], lineNumber);
    final primitive = LineGuidePrimitive(
      subpathId: parts[3],
      startM: RinkPoint(
        _number(parts[4], lineNumber, 'start x'),
        _number(parts[5], lineNumber, 'start y'),
      ),
      endM: RinkPoint(
        _number(parts[6], lineNumber, 'end x'),
        _number(parts[7], lineNumber, 'end y'),
      ),
    );
    _append(parts[1], edge, primitive, primitives, segments, lineNumber);
  }

  void _parseArc(
    List<String> parts,
    int lineNumber,
    List<GuidePrimitive> primitives,
    List<TaskSegment> segments,
  ) {
    if (parts.length != 9) {
      throw TaskNotationFormatException(
        lineNumber,
        'arc requires 8 values after the command.',
      );
    }
    final radiusM = _number(parts[6], lineNumber, 'radius');
    if (radiusM <= 0) {
      throw TaskNotationFormatException(lineNumber, 'radius must be positive.');
    }
    final edge = _edge(parts[2], lineNumber);
    final primitive = ArcGuidePrimitive(
      subpathId: parts[3],
      centerM: RinkPoint(
        _number(parts[4], lineNumber, 'centre x'),
        _number(parts[5], lineNumber, 'centre y'),
      ),
      radiusM: radiusM,
      startAngleRad: _degrees(parts[7], lineNumber, 'start angle'),
      sweepAngleRad: _degrees(parts[8], lineNumber, 'sweep angle'),
    );
    _append(parts[1], edge, primitive, primitives, segments, lineNumber);
  }

  void _append(
    String id,
    SkatingEdge edge,
    GuidePrimitive primitive,
    List<GuidePrimitive> primitives,
    List<TaskSegment> segments,
    int lineNumber,
  ) {
    if (id.isEmpty || primitive.subpathId.isEmpty) {
      throw TaskNotationFormatException(
        lineNumber,
        'Segment id and subpath id cannot be empty.',
      );
    }
    if (segments.any((segment) => segment.id == id)) {
      throw TaskNotationFormatException(
        lineNumber,
        'Duplicate segment id "$id".',
      );
    }
    primitives.add(primitive);
    segments.add(
      TaskSegment(
        id: id,
        primitiveIndex: primitives.length - 1,
        expectedEdge: edge,
      ),
    );
  }

  SkatingEdge _edge(String value, int lineNumber) {
    final match = RegExp(r'^([LR])([FB])([IO])$')
        .firstMatch(value.toUpperCase());
    if (match == null) {
      throw TaskNotationFormatException(
        lineNumber,
        'Edge "$value" must be LFO, LFI, LBO, LBI, RFO, RFI, RBO, or RBI.',
      );
    }
    return SkatingEdge(
      foot: match.group(1) == 'L' ? Foot.left : Foot.right,
      travel: match.group(2) == 'F'
          ? TravelDirection.forward
          : TravelDirection.backward,
      side: match.group(3) == 'I' ? EdgeSide.inside : EdgeSide.outside,
    );
  }

  double _number(String value, int lineNumber, String label) {
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) {
      throw TaskNotationFormatException(
        lineNumber,
        '$label must be a finite number.',
      );
    }
    return parsed;
  }

  double _degrees(String value, int lineNumber, String label) =>
      _number(value, lineNumber, label) * math.pi / 180;
}

class TaskNotationFormatException implements FormatException {
  const TaskNotationFormatException(this.line, this.message);

  final int line;

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => line == 0
      ? 'Task notation error: $message'
      : 'Task notation error on line $line: $message';
}
