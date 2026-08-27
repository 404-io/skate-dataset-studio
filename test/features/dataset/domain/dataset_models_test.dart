import 'package:flutter_test/flutter_test.dart';
import 'package:skate_dataset_studio/core/geometry/points.dart';
import 'package:skate_dataset_studio/core/rink/rink_profile.dart';
import 'package:skate_dataset_studio/features/dataset/domain/dataset_models.dart';
import 'package:skate_dataset_studio/features/tasks/domain/task_definition.dart';

void main() {
  const edge = SkatingEdge(
    foot: Foot.left,
    travel: TravelDirection.forward,
    side: EdgeSide.outside,
  );

  const task = TaskDefinition(
    id: 'task-1',
    title: 'Independent task',
    createdAtMs: 1,
    footChangeGapM: 0.22,
    primitives: [
      LineGuidePrimitive(
        subpathId: 'left-1',
        startM: RinkPoint(0, 0),
        endM: RinkPoint(1, 0),
      ),
    ],
    segments: [
      TaskSegment(id: 'segment-1', primitiveIndex: 0, expectedEdge: edge),
    ],
  );

  test('session persists its own task snapshot and manual calibration', () {
    const session = DatasetSession(
      id: 'session-1',
      taskSnapshot: task,
      videoUri: '/video/take.mp4',
      videoDurationMs: 1000,
      calibration: ManualRinkCalibration(
        rinkProfileId: 'training-60x30',
        imageCorners: [
          VideoPoint(0, 0),
          VideoPoint(1, 0),
          VideoPoint(1, 1),
          VideoPoint(0, 1),
        ],
        hockeyFeatureObservations: [
          RinkFeatureObservation(
            featureId: 'left-blue-far',
            imagePoint: VideoPoint(0.381, 0),
            rinkPoint: RinkPoint(22.86, 0),
          ),
        ],
      ),
      status: DatasetSessionStatus.readyForReview,
      createdAtMs: 1,
      updatedAtMs: 2,
    );

    final restored = DatasetSession.fromDatabaseRow(session.toDatabaseRow());

    expect(restored.taskSnapshot.title, task.title);
    expect(restored.calibration.rinkProfileId, 'training-60x30');
    expect(restored.calibration.hockeyFeatureObservations, hasLength(1));
    expect(
      restored.calibration.hockeyFeatureObservations.single.featureId,
      'left-blue-far',
    );
  });

  test('only clear reviewed observations are eligible for edge training', () {
    const eligible = DatasetReviewLabel(
      id: 'review-1',
      sessionId: 'session-1',
      segmentId: 'segment-1',
      expectedEdge: edge,
      reviewedEdge: edge,
      status: ReviewStatus.confirmed,
      visibility: ReviewVisibility.clear,
      updatedAtMs: 1,
    );
    const occluded = DatasetReviewLabel(
      id: 'review-2',
      sessionId: 'session-1',
      segmentId: 'segment-1',
      expectedEdge: edge,
      reviewedEdge: edge,
      status: ReviewStatus.confirmed,
      visibility: ReviewVisibility.occluded,
      updatedAtMs: 1,
    );

    expect(eligible.isTrainingLabel, isTrue);
    expect(occluded.isTrainingLabel, isFalse);
  });
}
