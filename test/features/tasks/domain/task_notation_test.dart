import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:skate_dataset_studio/features/tasks/domain/task_definition.dart';
import 'package:skate_dataset_studio/features/tasks/domain/task_notation.dart';

void main() {
  const parser = TaskNotationParser();

  test('parses explicit arcs, edge state, and physical foot-change gap', () {
    final definition = parser.parse(
      id: 'forward-eight',
      createdAtMs: 1000,
      source: '''
        # Deterministic guide coordinates are rink metres.
        task Forward outside eight
        gap 0.22
        arc left-circle LFO left-circle 10 8 3 180 -180
        arc right-circle RBO right-circle 16.22 8 3 180 180
      ''',
    );

    expect(definition.title, 'Forward outside eight');
    expect(definition.footChangeGapM, 0.22);
    expect(
      definition.segments.map((segment) => segment.expectedEdge.notation),
      ['LFO', 'RBO'],
    );
    expect(definition.validate(), isEmpty);

    final firstArc = definition.primitives.first as ArcGuidePrimitive;
    expect(firstArc.startAngleRad, closeTo(math.pi, 1e-12));
    expect(firstArc.sweepAngleRad, closeTo(-math.pi, 1e-12));
  });

  test('rejects a foot change that silently joins the same subpath', () {
    expect(
      () => parser.parse(
        id: 'bad-foot-change',
        createdAtMs: 1000,
        source: '''
          line first LFO shared 0 0 1 0
          line second RFO shared 1.3 0 2 0
        ''',
      ),
      throwsA(
        isA<TaskNotationFormatException>().having(
          (error) => error.message,
          'message',
          contains('separate subpath'),
        ),
      ),
    );
  });

  test('reports the source line for an invalid edge token', () {
    expect(
      () => parser.parse(
        id: 'bad-edge',
        createdAtMs: 1000,
        source: 'line first LXX line-a 0 0 1 0',
      ),
      throwsA(
        isA<TaskNotationFormatException>().having(
          (error) => error.line,
          'line',
          1,
        ),
      ),
    );
  });
}
