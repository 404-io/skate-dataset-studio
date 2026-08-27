import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../tasks/domain/task_definition.dart';
import '../domain/dataset_models.dart';

abstract interface class DatasetRepository {
  Future<List<TaskDefinition>> listTasks();
  Future<void> saveTask(TaskDefinition task);
  Future<List<DatasetSession>> listSessions();
  Future<List<DatasetReviewLabel>> listReviews(String sessionId);
  Future<void> saveSessionWithInitialReviews(
    DatasetSession session,
    List<DatasetReviewLabel> reviews,
  );
  Future<void> saveReview(DatasetReviewLabel review);
  Future<void> close();
}

/// All source videos remain files in app-managed storage or user-selected
/// storage. SQLite contains the URI, immutable task snapshot, calibration, and
/// review labels, not a duplicate video BLOB.
class SqliteDatasetRepository implements DatasetRepository {
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final location = path.join(
      await getDatabasesPath(),
      'skate_dataset_studio.sqlite',
    );
    final opened = await openDatabase(
      location,
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE task_definitions(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            definition_json TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL,
            updated_at_ms INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE capture_sessions(
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL,
            task_title TEXT NOT NULL,
            task_snapshot_json TEXT NOT NULL,
            video_uri TEXT NOT NULL,
            video_duration_ms INTEGER NOT NULL,
            calibration_json TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL,
            updated_at_ms INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE segment_reviews(
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            segment_id TEXT NOT NULL,
            expected_edge_json TEXT NOT NULL,
            reviewed_edge_json TEXT,
            status TEXT NOT NULL,
            visibility TEXT NOT NULL,
            start_ms INTEGER,
            end_ms INTEGER,
            reviewer_confidence INTEGER,
            note TEXT NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            FOREIGN KEY(session_id) REFERENCES capture_sessions(id) ON DELETE CASCADE
          )
        ''');
        await database.execute(
          'CREATE INDEX segment_reviews_session_index ON segment_reviews(session_id, segment_id)',
        );
      },
    );
    _database = opened;
    return opened;
  }

  @override
  Future<List<TaskDefinition>> listTasks() async {
    final rows = await (await _db).query(
      'task_definitions',
      orderBy: 'created_at_ms DESC',
    );
    return rows
        .map(
          (row) => TaskDefinition.fromJson(
            Map<String, Object?>.from(
              jsonDecode(row['definition_json']! as String) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveTask(TaskDefinition task) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (await _db).insert('task_definitions', {
      'id': task.id,
      'title': task.title,
      'definition_json': jsonEncode(task.toJson()),
      'created_at_ms': task.createdAtMs,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<DatasetSession>> listSessions() async {
    final rows = await (await _db).query(
      'capture_sessions',
      orderBy: 'created_at_ms DESC',
    );
    return rows
        .map(
          (row) =>
              DatasetSession.fromDatabaseRow(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<DatasetReviewLabel>> listReviews(String sessionId) async {
    final rows = await (await _db).query(
      'segment_reviews',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'segment_id ASC',
    );
    return rows
        .map(
          (row) => DatasetReviewLabel.fromDatabaseRow(
            Map<String, Object?>.from(row),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveSessionWithInitialReviews(
    DatasetSession session,
    List<DatasetReviewLabel> reviews,
  ) async {
    if (reviews.any((review) => review.sessionId != session.id)) {
      throw ArgumentError(
        'Every initial review must belong to the saved session.',
      );
    }
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.insert(
        'capture_sessions',
        session.toDatabaseRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final review in reviews) {
        await transaction.insert(
          'segment_reviews',
          review.toDatabaseRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> saveReview(DatasetReviewLabel review) async {
    await (await _db).insert(
      'segment_reviews',
      review.toDatabaseRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
