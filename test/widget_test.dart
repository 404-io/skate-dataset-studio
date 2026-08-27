import 'package:flutter_test/flutter_test.dart';
import 'package:skate_dataset_studio/core/geometry/points.dart';
import 'package:skate_dataset_studio/features/tasks/domain/task_definition.dart';

void main() {
  test('a foot change requires a separate path and a real gap', () {
    const task = TaskDefinition(
      id: 'task',
      title: 'Gap check',
      createdAtMs: 1,
      footChangeGapM: 0.22,
      primitives: [
        LineGuidePrimitive(
          subpathId: 'left-path',
          startM: RinkPoint(0, 0),
          endM: RinkPoint(1, 0),
        ),
        LineGuidePrimitive(
          subpathId: 'right-path',
          startM: RinkPoint(1.23, 0),
          endM: RinkPoint(2, 0),
        ),
      ],
      segments: [
        TaskSegment(
          id: 'left',
          primitiveIndex: 0,
          expectedEdge: SkatingEdge(
            foot: Foot.left,
            travel: TravelDirection.forward,
            side: EdgeSide.outside,
          ),
        ),
        TaskSegment(
          id: 'right',
          primitiveIndex: 1,
          expectedEdge: SkatingEdge(
            foot: Foot.right,
            travel: TravelDirection.backward,
            side: EdgeSide.inside,
          ),
        ),
      ],
    );

    expect(task.validate(), isEmpty);
  });
}
