import 'dart:convert';

import '../../../core/rink/rink_profile.dart';
import '../../tasks/domain/task_definition.dart';

enum DatasetSessionStatus { draft, readyForReview, reviewed }

enum ReviewStatus { unreviewed, confirmed, corrected }

enum ReviewVisibility { clear, occluded, tooSmall }

/// A recording refers to a frozen task snapshot, so editing a task later cannot
/// silently rewrite the expectation that accompanied the original video.
class DatasetSession {
  const DatasetSession({
    required this.id,
    required this.taskSnapshot,
    required this.videoUri,
    required this.videoDurationMs,
    required this.calibration,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final TaskDefinition taskSnapshot;
  final String videoUri;
  final int videoDurationMs;
  final ManualRinkCalibration calibration;
  final DatasetSessionStatus status;
  final int createdAtMs;
  final int updatedAtMs;

  Map<String, Object?> toDatabaseRow() => {
    'id': id,
    'task_id': taskSnapshot.id,
    'task_title': taskSnapshot.title,
    'task_snapshot_json': jsonEncode(taskSnapshot.toJson()),
    'video_uri': videoUri,
    'video_duration_ms': videoDurationMs,
    'calibration_json': jsonEncode(calibration.toJson()),
    'status': status.name,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
  };

  factory DatasetSession.fromDatabaseRow(Map<String, Object?> row) =>
      DatasetSession(
        id: row['id']! as String,
        taskSnapshot: TaskDefinition.fromJson(
          Map<String, Object?>.from(
            jsonDecode(row['task_snapshot_json']! as String) as Map,
          ),
        ),
        videoUri: row['video_uri']! as String,
        videoDurationMs: row['video_duration_ms']! as int,
        calibration: ManualRinkCalibration.fromJson(
          Map<String, Object?>.from(
            jsonDecode(row['calibration_json']! as String) as Map,
          ),
        ),
        status: DatasetSessionStatus.values.byName(row['status']! as String),
        createdAtMs: row['created_at_ms']! as int,
        updatedAtMs: row['updated_at_ms']! as int,
      );
}

/// Expected and reviewed edges are deliberately separate. Only a clear,
/// expert-confirmed observation qualifies for future classifier training.
class DatasetReviewLabel {
  const DatasetReviewLabel({
    required this.id,
    required this.sessionId,
    required this.segmentId,
    required this.expectedEdge,
    required this.status,
    required this.visibility,
    required this.updatedAtMs,
    this.reviewedEdge,
    this.startMs,
    this.endMs,
    this.reviewerConfidence,
    this.note = '',
  }) : assert(startMs == null || endMs == null || startMs <= endMs),
       assert(
         status == ReviewStatus.unreviewed || reviewedEdge != null,
         'A reviewed label must record the observed edge.',
       );

  final String id;
  final String sessionId;
  final String segmentId;
  final SkatingEdge expectedEdge;
  final ReviewStatus status;
  final ReviewVisibility visibility;
  final int updatedAtMs;
  final SkatingEdge? reviewedEdge;
  final int? startMs;
  final int? endMs;
  final int? reviewerConfidence;
  final String note;

  bool get isTrainingLabel =>
      visibility == ReviewVisibility.clear &&
      (status == ReviewStatus.confirmed || status == ReviewStatus.corrected) &&
      reviewedEdge != null;

  DatasetReviewLabel copyWith({
    required ReviewStatus status,
    required ReviewVisibility visibility,
    SkatingEdge? reviewedEdge,
    bool clearReviewedEdge = false,
    String? note,
    int? updatedAtMs,
  }) => DatasetReviewLabel(
    id: id,
    sessionId: sessionId,
    segmentId: segmentId,
    expectedEdge: expectedEdge,
    status: status,
    visibility: visibility,
    reviewedEdge: clearReviewedEdge
        ? null
        : (reviewedEdge ?? this.reviewedEdge),
    startMs: startMs,
    endMs: endMs,
    reviewerConfidence: reviewerConfidence,
    note: note ?? this.note,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );

  Map<String, Object?> toDatabaseRow() => {
    'id': id,
    'session_id': sessionId,
    'segment_id': segmentId,
    'expected_edge_json': jsonEncode(expectedEdge.toJson()),
    'reviewed_edge_json': reviewedEdge == null
        ? null
        : jsonEncode(reviewedEdge!.toJson()),
    'status': status.name,
    'visibility': visibility.name,
    'start_ms': startMs,
    'end_ms': endMs,
    'reviewer_confidence': reviewerConfidence,
    'note': note,
    'updated_at_ms': updatedAtMs,
  };

  factory DatasetReviewLabel.fromDatabaseRow(Map<String, Object?> row) =>
      DatasetReviewLabel(
        id: row['id']! as String,
        sessionId: row['session_id']! as String,
        segmentId: row['segment_id']! as String,
        expectedEdge: SkatingEdge.fromJson(
          Map<String, Object?>.from(
            jsonDecode(row['expected_edge_json']! as String) as Map,
          ),
        ),
        reviewedEdge: row['reviewed_edge_json'] == null
            ? null
            : SkatingEdge.fromJson(
                Map<String, Object?>.from(
                  jsonDecode(row['reviewed_edge_json']! as String) as Map,
                ),
              ),
        status: ReviewStatus.values.byName(row['status']! as String),
        visibility: ReviewVisibility.values.byName(
          row['visibility']! as String,
        ),
        startMs: row['start_ms'] as int?,
        endMs: row['end_ms'] as int?,
        reviewerConfidence: row['reviewer_confidence'] as int?,
        note: row['note']! as String,
        updatedAtMs: row['updated_at_ms']! as int,
      );
}

String newDatasetId(String prefix, int timestampMs, int sequence) =>
    '$prefix-$timestampMs-$sequence';
