import 'package:flutter/material.dart';

import '../../dataset/data/dataset_repository.dart';
import '../../dataset/domain/dataset_models.dart';
import '../domain/task_definition.dart';
import '../domain/task_notation.dart';

/// Creates a task from the deterministic notation shared by guide rendering,
/// video review, and future AR/VR clients.
class TaskNotationEditorScreen extends StatefulWidget {
  const TaskNotationEditorScreen({required this.repository, super.key});

  final DatasetRepository repository;

  @override
  State<TaskNotationEditorScreen> createState() =>
      _TaskNotationEditorScreenState();
}

class _TaskNotationEditorScreenState extends State<TaskNotationEditorScreen> {
  static const _initialSource = '''
# id edge subpath centre-x-m centre-y-m radius-m start-deg sweep-deg
task Forward outside eight
gap 0.22
arc left-circle LFO left-circle 10 8 3 180 -180
arc right-circle RBO right-circle 16.22 8 3 180 180
''';

  static const _parser = TaskNotationParser();

  late final TextEditingController _sourceController;
  TaskDefinition? _preview;
  String? _validationError;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController(text: _initialSource);
    _sourceController.addListener(_refreshPreview);
    _refreshPreview();
  }

  @override
  void dispose() {
    _sourceController
      ..removeListener(_refreshPreview)
      ..dispose();
    super.dispose();
  }

  void _refreshPreview() {
    try {
      final definition = _parser.parse(
        source: _sourceController.text,
        id: 'preview',
        createdAtMs: 0,
      );
      setState(() {
        _preview = definition;
        _validationError = null;
      });
    } on TaskNotationFormatException catch (error) {
      setState(() {
        _preview = null;
        _validationError = error.line == 0
            ? error.message
            : '${error.line}行目: ${error.message}';
      });
    }
  }

  Future<void> _save() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final task = _parser.parse(
        source: _sourceController.text,
        id: newDatasetId('task', now, 0),
        createdAtMs: now,
      );
      setState(() => _saving = true);
      await widget.repository.saveTask(task);
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      Navigator.pop(context, true);
    } on TaskNotationFormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _validationError = error.line == 0
            ? error.message
            : '${error.line}行目: ${error.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('課題記法エディタ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '課題図形と期待エッジを同じ記法で保存します。座標はリンク上のメートルです。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _sourceController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: '課題記法',
                    helperText:
                        'arc: id edge subpath cx cy radius startDeg sweepDeg',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _NotationPreview(
                definition: preview,
                validationError: _validationError,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: preview == null || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? '保存中…' : '検証済みの課題を保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotationPreview extends StatelessWidget {
  const _NotationPreview({
    required this.definition,
    required this.validationError,
  });

  final TaskDefinition? definition;
  final String? validationError;

  @override
  Widget build(BuildContext context) {
    final error = validationError;
    if (error != null) {
      return Card(
        color: const Color(0xfffff1ef),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.error_outline, color: Color(0xffb42318)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
        ),
      );
    }

    final task = definition;
    if (task == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('検証済み: ${task.title}'),
            const SizedBox(height: 6),
            Text(
              '${task.primitives.length}経路 · 足替えギャップ ${task.footChangeGapM.toStringAsFixed(2)} m',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final segment in task.segments)
                  Chip(
                    label: Text(
                      '${segment.id}: ${segment.expectedEdge.notation}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
