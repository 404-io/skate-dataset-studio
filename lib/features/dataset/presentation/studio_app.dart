import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/geometry/points.dart';
import '../../../core/rink/rink_profile.dart';
import '../../tasks/domain/task_definition.dart';
import '../../tasks/domain/supported_task_templates.dart';
import '../data/dataset_repository.dart';
import '../domain/dataset_models.dart';

class DatasetStudioApp extends StatefulWidget {
  const DatasetStudioApp({super.key});

  @override
  State<DatasetStudioApp> createState() => _DatasetStudioAppState();
}

class _DatasetStudioAppState extends State<DatasetStudioApp> {
  final DatasetRepository _repository = SqliteDatasetRepository();
  var _selectedIndex = 0;
  late final Future<void> _catalogReady;

  static const _titles = ['課題', '収録', 'データセット'];

  @override
  void initState() {
    super.initState();
    _catalogReady = _seedSupportedTaskTemplates();
  }

  Future<void> _seedSupportedTaskTemplates() async {
    for (final template in buildSupportedTaskTemplates()) {
      await _repository.saveTask(template.task);
    }
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skate Dataset Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xff165d8d),
          onPrimary: Colors.white,
          secondary: Color(0xffe66b45),
          surface: Colors.white,
          onSurface: Color(0xff17212b),
          outline: Color(0xffdce3e9),
        ),
        scaffoldBackgroundColor: const Color(0xfff4f7f9),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xff17212b),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xfff8fafb),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffdce3e9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffdce3e9)),
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: Text(_titles[_selectedIndex])),
        body: FutureBuilder<void>(
          future: _catalogReady,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('固定課題を準備できませんでした。アプリを再起動してください。'),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return IndexedStack(
              index: _selectedIndex,
              children: [
                TaskLibraryScreen(repository: _repository),
                CaptureScreen(repository: _repository),
                DatasetSessionListScreen(repository: _repository),
              ],
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: '課題',
            ),
            NavigationDestination(
              icon: Icon(Icons.video_camera_back_outlined),
              selectedIcon: Icon(Icons.video_camera_back),
              label: '収録',
            ),
            NavigationDestination(
              icon: Icon(Icons.dataset_outlined),
              selectedIcon: Icon(Icons.dataset),
              label: 'データセット',
            ),
          ],
        ),
      ),
    );
  }
}

class TaskLibraryScreen extends StatefulWidget {
  const TaskLibraryScreen({required this.repository, super.key});

  final DatasetRepository repository;

  @override
  State<TaskLibraryScreen> createState() => _TaskLibraryScreenState();
}

class _TaskLibraryScreenState extends State<TaskLibraryScreen> {
  late Future<List<TaskDefinition>> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = widget.repository.listTasks();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskDefinition>>(
      future: _tasks,
      builder: (context, snapshot) {
        final tasks = (snapshot.data ?? const <TaskDefinition>[])
            .where((task) => supportedTaskIds.contains(task.id))
            .toList(growable: false);
        final templatesById = {
          for (final template in buildSupportedTaskTemplates())
            template.task.id: template,
        };
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('課題ライブラリ', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'この初期版では、指定されたフォア・チェンジ・ハーフ・サークル（左右）とワルツ（スリー）ステップだけを収録・比較します。',
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (tasks.isEmpty)
              const _EmptyCard(
                icon: Icons.route_outlined,
                text: '固定課題を読み込めませんでした。アプリを再起動してください。',
              )
            else
              ...tasks.map((task) {
                final template = templatesById[task.id]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(template.summary),
                          const SizedBox(height: 10),
                          Text(
                            '期待エッジ: ${task.segments.map((segment) => segment.expectedEdge.notation).join(' → ')}',
                          ),
                          const SizedBox(height: 8),
                          ...template.coachingPoints.map(
                            (point) => Text('• $point'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({required this.repository, super.key});

  final DatasetRepository repository;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  VideoPlayerController? _videoController;
  String? _videoPath;
  final _imageCorners = <VideoPoint>[];
  final _hockeyFeatureObservations = <RinkFeatureObservation>[];
  var _collectingHockeyFeatures = false;
  late Future<List<TaskDefinition>> _tasks;
  String? _selectedTaskId;
  String _selectedProfileId = rinkProfiles.first.id;
  String _message = '課題と動画を選び、リンク外周の4点を順にタップしてください。';

  @override
  void initState() {
    super.initState();
    _tasks = widget.repository.listTasks();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picked = await FilePicker.pickFiles(type: FileType.video);
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) {
      return;
    }
    final next = VideoPlayerController.file(File(path));
    try {
      await next.initialize();
      await _videoController?.dispose();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _videoController = next;
        _videoPath = path;
        _imageCorners.clear();
        _hockeyFeatureObservations.clear();
        _collectingHockeyFeatures = false;
        _message = '左奥 → 右奥 → 右手前 → 左手前の順に、リンク外周を4点タップします。';
      });
    } catch (_) {
      await next.dispose();
      if (mounted) {
        setState(() => _message = '動画を開けませんでした。端末内の動画を選んでください。');
      }
    }
  }

  void _addCorner(TapDownDetails details, BoxConstraints constraints) {
    if (_videoController == null || _imageCorners.length == 4) {
      return;
    }
    final point = VideoPoint(
      (details.localPosition.dx / constraints.maxWidth).clamp(0, 1).toDouble(),
      (details.localPosition.dy / constraints.maxHeight).clamp(0, 1).toDouble(),
    );
    setState(() {
      _imageCorners.add(point);
      _message = _imageCorners.length == 4
          ? '4点を検証して、収録セッションを作成できます。'
          : '校正点 ${_imageCorners.length}/4。次の角をタップしてください。';
    });
  }

  RinkProfile get _selectedProfile => rinkProfileById(_selectedProfileId);

  HockeyLineFeaturePoint? get _nextHockeyFeature {
    final features = _selectedProfile.hockeyFeaturePoints;
    if (_hockeyFeatureObservations.length >= features.length) {
      return null;
    }
    return features[_hockeyFeatureObservations.length];
  }

  ManualRinkCalibration? get _currentCalibration {
    if (_imageCorners.length != 4) {
      return null;
    }
    try {
      final calibration = ManualRinkCalibration(
        rinkProfileId: _selectedProfileId,
        imageCorners: _imageCorners,
        hockeyFeatureObservations: _hockeyFeatureObservations,
      );
      calibration.imageToRink;
      return calibration;
    } on Object {
      return null;
    }
  }

  void _addCalibrationPoint(
    TapDownDetails details,
    BoxConstraints constraints,
  ) {
    if (_imageCorners.length < 4) {
      _addCorner(details, constraints);
      return;
    }
    if (!_collectingHockeyFeatures || _videoController == null) {
      return;
    }
    final feature = _nextHockeyFeature;
    if (feature == null) {
      setState(() {
        _collectingHockeyFeatures = false;
        _message = 'ホッケーライン特徴点をすべて記録しました。';
      });
      return;
    }
    final point = VideoPoint(
      (details.localPosition.dx / constraints.maxWidth).clamp(0, 1).toDouble(),
      (details.localPosition.dy / constraints.maxHeight).clamp(0, 1).toDouble(),
    );
    setState(() {
      _hockeyFeatureObservations.add(
        RinkFeatureObservation(
          featureId: feature.id,
          imagePoint: point,
          rinkPoint: feature.rinkPoint,
        ),
      );
      final next = _nextHockeyFeature;
      if (next == null) {
        _collectingHockeyFeatures = false;
        _message = 'ホッケーライン特徴点をすべて記録しました。';
      } else {
        _message = '次の特徴点: ${next.label} をタップしてください。';
      }
    });
  }

  void _toggleHockeyFeatureCollection() {
    if (_imageCorners.length != 4) {
      return;
    }
    setState(() {
      _collectingHockeyFeatures = !_collectingHockeyFeatures;
      final feature = _nextHockeyFeature;
      _message = _collectingHockeyFeatures && feature != null
          ? 'ホッケーラインの ${feature.label} をタップしてください。'
          : 'ホッケーライン特徴点の追加を停止しました。';
    });
  }

  Future<void> _saveSession(List<TaskDefinition> tasks) async {
    final videoController = _videoController;
    final videoPath = _videoPath;
    final taskId = _selectedTaskId;
    if (videoController == null ||
        videoPath == null ||
        taskId == null ||
        _imageCorners.length != 4) {
      setState(() => _message = '課題、動画、リンク外周の4点をすべて指定してください。');
      return;
    }
    final task = tasks.firstWhere((candidate) => candidate.id == taskId);
    final calibration = ManualRinkCalibration(
      rinkProfileId: _selectedProfileId,
      imageCorners: List<VideoPoint>.unmodifiable(_imageCorners),
      hockeyFeatureObservations: List<RinkFeatureObservation>.unmodifiable(
        _hockeyFeatureObservations,
      ),
    );
    try {
      calibration.imageToRink;
    } on Object {
      setState(() => _message = '4点から校正行列を作れません。広く離れた4点を指定してください。');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionId = newDatasetId('session', now, 0);
    final session = DatasetSession(
      id: sessionId,
      taskSnapshot: task,
      videoUri: videoPath,
      videoDurationMs: videoController.value.duration.inMilliseconds,
      calibration: calibration,
      status: DatasetSessionStatus.readyForReview,
      createdAtMs: now,
      updatedAtMs: now,
    );
    final labels = [
      for (var index = 0; index < task.segments.length; index++)
        DatasetReviewLabel(
          id: newDatasetId('review', now, index),
          sessionId: sessionId,
          segmentId: task.segments[index].id,
          expectedEdge: task.segments[index].expectedEdge,
          status: ReviewStatus.unreviewed,
          visibility: ReviewVisibility.clear,
          updatedAtMs: now,
        ),
    ];
    await widget.repository.saveSessionWithInitialReviews(session, labels);
    if (!mounted) {
      return;
    }
    setState(() {
      _message = '収録セッションを保存しました。データセット画面で専門家レビューを行えます。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _videoController;
    return FutureBuilder<List<TaskDefinition>>(
      future: _tasks,
      builder: (context, snapshot) {
        final tasks = (snapshot.data ?? const <TaskDefinition>[])
            .where((task) => supportedTaskIds.contains(task.id))
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('単眼動画の収録', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_message),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTaskId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '課題'),
                      items: tasks
                          .map(
                            (task) => DropdownMenuItem(
                              value: task.id,
                              child: Text(task.title),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: tasks.isEmpty
                          ? null
                          : (value) => setState(() => _selectedTaskId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProfileId,
                      decoration: const InputDecoration(labelText: 'リンク規格'),
                      items: rinkProfiles
                          .map(
                            (profile) => DropdownMenuItem(
                              value: profile.id,
                              child: Text(profile.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedProfileId = value;
                            _hockeyFeatureObservations.clear();
                            _collectingHockeyFeatures = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.video_file_outlined),
                        label: const Text('動画を選ぶ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: videoController?.value.aspectRatio ?? 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onTapDown: (details) =>
                        _addCalibrationPoint(details, constraints),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: const Color(0xff111d24),
                          child: videoController == null
                              ? const Center(
                                  child: Text(
                                    '動画を選択すると校正画面が表示されます',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              : VideoPlayer(videoController),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _CalibrationPainter(
                              corners: _imageCorners,
                              hockeyLines: _selectedProfile.hockeyLines,
                              hockeyFeatureObservations:
                                  _hockeyFeatureObservations,
                              calibration: _currentCalibration,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ホッケーライン特徴点（任意・精度確認用）'),
                    const SizedBox(height: 4),
                    Text(
                      '${_hockeyFeatureObservations.length}/${_selectedProfile.hockeyFeaturePoints.length} 点を記録',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          _imageCorners.length != 4 ||
                              _nextHockeyFeature == null
                          ? null
                          : _toggleHockeyFeatureCollection,
                      icon: Icon(
                        _collectingHockeyFeatures
                            ? Icons.pause_circle_outline
                            : Icons.add_location_alt_outlined,
                      ),
                      label: Text(
                        _collectingHockeyFeatures
                            ? '特徴点の追加を停止'
                            : 'ホッケーライン特徴点を追加',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _imageCorners.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _imageCorners.clear();
                        _hockeyFeatureObservations.clear();
                        _collectingHockeyFeatures = false;
                        _message = '校正点をリセットしました。左奥から指定し直してください。';
                      });
                    },
              icon: const Icon(Icons.restart_alt),
              label: const Text('校正点をリセット'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: tasks.isEmpty ? null : () => _saveSession(tasks),
              icon: const Icon(Icons.save_outlined),
              label: const Text('収録セッションを保存'),
            ),
          ],
        );
      },
    );
  }
}

class DatasetSessionListScreen extends StatefulWidget {
  const DatasetSessionListScreen({required this.repository, super.key});

  final DatasetRepository repository;

  @override
  State<DatasetSessionListScreen> createState() =>
      _DatasetSessionListScreenState();
}

class _DatasetSessionListScreenState extends State<DatasetSessionListScreen> {
  late Future<List<DatasetSession>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = widget.repository.listSessions();
  }

  void _reload() {
    setState(() => _sessions = widget.repository.listSessions());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DatasetSession>>(
      future: _sessions,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <DatasetSession>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '収録データ',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('期待エッジと専門家確認済みエッジを別々に保存します。'),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (sessions.isEmpty)
              const _EmptyCard(
                icon: Icons.dataset_outlined,
                text: '収録セッションはまだありません。',
              )
            else
              ...sessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ReviewScreen(
                              repository: widget.repository,
                              session: session,
                            ),
                          ),
                        );
                        if (mounted) {
                          _reload();
                        }
                      },
                      leading: const CircleAvatar(
                        child: Icon(Icons.fact_check_outlined),
                      ),
                      title: Text(session.taskSnapshot.title),
                      subtitle: Text(
                        '${session.status.name} · ${session.taskSnapshot.segments.length} segments',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    required this.repository,
    required this.session,
    super.key,
  });

  final DatasetRepository repository;
  final DatasetSession session;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<DatasetReviewLabel>> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = widget.repository.listReviews(widget.session.id);
  }

  void _reload() {
    setState(() => _reviews = widget.repository.listReviews(widget.session.id));
  }

  Future<void> _editReview(DatasetReviewLabel review) async {
    var status = review.status;
    var visibility = review.visibility;
    var edge = review.reviewedEdge ?? review.expectedEdge;
    final noteController = TextEditingController(text: review.note);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Wrap(
            runSpacing: 14,
            children: [
              Text(
                '区間 ${review.segmentId}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('課題の期待値: ${review.expectedEdge.notation}'),
              DropdownButtonFormField<ReviewStatus>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'レビュー状態'),
                items: ReviewStatus.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_reviewStatusLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setSheetState(() => status = value);
                  }
                },
              ),
              DropdownButtonFormField<ReviewVisibility>(
                initialValue: visibility,
                decoration: const InputDecoration(labelText: '視認性'),
                items: ReviewVisibility.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_visibilityLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setSheetState(() => visibility = value);
                  }
                },
              ),
              if (status != ReviewStatus.unreviewed)
                DropdownButtonFormField<String>(
                  initialValue: edge.notation,
                  decoration: const InputDecoration(labelText: '観測されたエッジ'),
                  items: _edgeChoices.entries
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(item.key),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => edge = _edgeChoices[value]!);
                    }
                  },
                ),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'レビュー注記'),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final updated = status == ReviewStatus.unreviewed
                        ? review.copyWith(
                            status: status,
                            visibility: visibility,
                            clearReviewedEdge: true,
                            note: noteController.text.trim(),
                            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                          )
                        : review.copyWith(
                            status: status,
                            visibility: visibility,
                            reviewedEdge: edge,
                            note: noteController.text.trim(),
                            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                          );
                    await widget.repository.saveReview(updated);
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('レビューを保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.session.taskSnapshot.title)),
      body: FutureBuilder<List<DatasetReviewLabel>>(
        future: _reviews,
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? const <DatasetReviewLabel>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('専門家レビュー', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('確認済みかつ足元が明瞭なラベルだけを、将来のエッジ分類学習へ渡します。'),
              const SizedBox(height: 16),
              ...reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      onTap: () => _editReview(review),
                      title: Text(
                        '${review.segmentId} · expected ${review.expectedEdge.notation}',
                      ),
                      subtitle: Text(
                        review.status == ReviewStatus.unreviewed
                            ? '未確認'
                            : 'observed ${review.reviewedEdge!.notation}',
                      ),
                      trailing: review.isTrainingLabel
                          ? const Icon(
                              Icons.verified_rounded,
                              color: Color(0xff16805a),
                            )
                          : const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalibrationPainter extends CustomPainter {
  const _CalibrationPainter({
    required this.corners,
    required this.hockeyLines,
    required this.hockeyFeatureObservations,
    required this.calibration,
  });

  final List<VideoPoint> corners;
  final List<HockeyLineReference> hockeyLines;
  final List<RinkFeatureObservation> hockeyFeatureObservations;
  final ManualRinkCalibration? calibration;

  @override
  void paint(Canvas canvas, Size size) {
    final points = corners;
    final activeCalibration = calibration;
    if (activeCalibration != null) {
      try {
        final homography = activeCalibration.imageToRink;
        for (final hockeyLine in hockeyLines) {
          final start = homography.rinkToImage(hockeyLine.startM);
          final end = homography.rinkToImage(hockeyLine.endM);
          final paint = Paint()
            ..color = hockeyLine.id.contains('blue')
                ? const Color(0xff2888d8)
                : const Color(0xffed4b42)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
          canvas.drawLine(
            Offset(start.u * size.width, start.v * size.height),
            Offset(end.u * size.width, end.v * size.height),
            paint,
          );
        }
      } on Object {
        // Invalid calibration is represented by the absence of projected lines.
      }
    }
    final line = Paint()
      ..color = const Color(0xffffcf48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dot = Paint()..color = const Color(0xffffcf48);
    if (points.length > 1) {
      final path = Path()
        ..moveTo(points.first.u * size.width, points.first.v * size.height);
      for (final point in points.skip(1)) {
        path.lineTo(point.u * size.width, point.v * size.height);
      }
      if (points.length == 4) {
        path.close();
      }
      canvas.drawPath(path, line);
    }
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final center = Offset(point.u * size.width, point.v * size.height);
      canvas.drawCircle(center, 9, dot);
      final text = TextPainter(
        text: TextSpan(
          text: (index + 1).toString(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
    final featureDot = Paint()..color = const Color(0xff71e6dd);
    for (final observation in hockeyFeatureObservations) {
      final point = observation.imagePoint;
      canvas.drawCircle(
        Offset(point.u * size.width, point.v * size.height),
        7,
        featureDot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalibrationPainter oldDelegate) =>
      oldDelegate.corners.length != corners.length ||
      oldDelegate.hockeyFeatureObservations.length !=
          hockeyFeatureObservations.length ||
      oldDelegate.calibration?.rinkProfileId != calibration?.rinkProfileId;
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 36, color: const Color(0xff6c7b88)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

const _edgeChoices = <String, SkatingEdge>{
  'LFO': SkatingEdge(
    foot: Foot.left,
    travel: TravelDirection.forward,
    side: EdgeSide.outside,
  ),
  'LFI': SkatingEdge(
    foot: Foot.left,
    travel: TravelDirection.forward,
    side: EdgeSide.inside,
  ),
  'LBO': SkatingEdge(
    foot: Foot.left,
    travel: TravelDirection.backward,
    side: EdgeSide.outside,
  ),
  'LBI': SkatingEdge(
    foot: Foot.left,
    travel: TravelDirection.backward,
    side: EdgeSide.inside,
  ),
  'RFO': SkatingEdge(
    foot: Foot.right,
    travel: TravelDirection.forward,
    side: EdgeSide.outside,
  ),
  'RFI': SkatingEdge(
    foot: Foot.right,
    travel: TravelDirection.forward,
    side: EdgeSide.inside,
  ),
  'RBO': SkatingEdge(
    foot: Foot.right,
    travel: TravelDirection.backward,
    side: EdgeSide.outside,
  ),
  'RBI': SkatingEdge(
    foot: Foot.right,
    travel: TravelDirection.backward,
    side: EdgeSide.inside,
  ),
};

String _reviewStatusLabel(ReviewStatus status) => switch (status) {
  ReviewStatus.unreviewed => '未確認',
  ReviewStatus.confirmed => '確認済み',
  ReviewStatus.corrected => '修正済み',
};

String _visibilityLabel(ReviewVisibility visibility) => switch (visibility) {
  ReviewVisibility.clear => '明瞭',
  ReviewVisibility.occluded => '遮蔽',
  ReviewVisibility.tooSmall => '足元が小さすぎる',
};
