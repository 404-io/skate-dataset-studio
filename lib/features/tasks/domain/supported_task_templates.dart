import 'task_definition.dart';
import 'task_notation.dart';

class SupportedTaskTemplate {
  const SupportedTaskTemplate({
    required this.task,
    required this.summary,
    required this.coachingPoints,
  });

  final TaskDefinition task;
  final String summary;
  final List<String> coachingPoints;
}

const supportedTaskIds = <String>{
  'forward-change-half-circle-right',
  'forward-change-half-circle-left',
  'waltz-three-step',
};

/// The initial product scope deliberately contains only the three supplied
/// practice figures. Their fixed task IDs make each capture comparable while
/// preserving a task snapshot inside every session.
List<SupportedTaskTemplate> buildSupportedTaskTemplates({int createdAtMs = 1}) {
  const parser = TaskNotationParser();
  return [
    SupportedTaskTemplate(
      task: parser.parse(
        id: 'forward-change-half-circle-right',
        createdAtMs: createdAtMs,
        source: '''
          task フォア・チェンジ・ハーフ・サークル（右足スタート）
          gap 0.24
          # RFO -> RFI changes edge on the right foot; LFI begins after a foot change.
          arc rfo-1 RFO right-1 9 15 3 180 -180
          arc rfi-1 RFI right-1 15 15 3 180 180
          arc lfi-1 LFI left-1 21.24 15 3 180 -180
          arc lfo-1 LFO left-1 27.24 15 3 180 180
          arc rfo-2 RFO right-2 33.48 15 3 180 -180
          arc rfi-2 RFI right-2 39.48 15 3 180 180
          arc lfi-2 LFI left-2 45.72 15 3 180 -180
          arc lfo-2 LFO left-2 51.72 15 3 180 180
        ''',
      ),
      summary: 'RFO → RFI → LFI → LFO。右足から始める半円の連続です。',
      coachingPoints: const [
        'ワブルを作らない。',
        '隣り合う半円の大きさをそろえる。',
        '半円を小さくしすぎず、エッジに乗る。',
      ],
    ),
    SupportedTaskTemplate(
      task: parser.parse(
        id: 'forward-change-half-circle-left',
        createdAtMs: createdAtMs,
        source: '''
          task フォア・チェンジ・ハーフ・サークル（左足スタート）
          gap 0.24
          # Mirrored edge order of the right-start task.
          arc lfo-1 LFO left-1 9 15 3 180 180
          arc lfi-1 LFI left-1 15 15 3 180 -180
          arc rfi-1 RFI right-1 21.24 15 3 180 180
          arc rfo-1 RFO right-1 27.24 15 3 180 -180
          arc lfo-2 LFO left-2 33.48 15 3 180 180
          arc lfi-2 LFI left-2 39.48 15 3 180 -180
          arc rfi-2 RFI right-2 45.72 15 3 180 180
          arc rfo-2 RFO right-2 51.72 15 3 180 -180
        ''',
      ),
      summary: 'LFO → LFI → RFI → RFO。左足から始める鏡像の半円連続です。',
      coachingPoints: const [
        'ワブルを作らない。',
        '左右の半円をほぼ同じ直径に保つ。',
        '足替えの境界では別の軌跡として滑る。',
      ],
    ),
    SupportedTaskTemplate(
      task: parser.parse(
        id: 'waltz-three-step',
        createdAtMs: createdAtMs,
        source: '''
          task ワルツ（スリー）ステップ（3でターン）
          gap 0.24
          # Count 1-3: RFO enters the turn. The next RBO segment is the exit of the three turn.
          arc rfo-count-1-to-3 RFO right-three-1 9 15 3 180 -120
          arc rbo-after-three-turn RBO right-three-1 9 15 3 60 120
          arc lbo-step LBO left-three-1 9.24 15 3 180 -180
          arc rfo-step RFO right-three-2 15.48 15 3 180 180
          arc lfo-step LFO left-three-2 21.72 15 3 180 -180
          arc rfo-repeat RFO right-three-3 27.96 15 3 180 180
          arc lfo-repeat LFO left-three-3 34.20 15 3 180 -180
        ''',
      ),
      summary: 'RFOで1〜3を進み、3でRBOへスリーターン。その後LBO・RFO・LFOへ続けます。',
      coachingPoints: const [
        '3でターンする。',
        'ターン後から6までワブルを作らずに乗る。',
        '直線にせず、カーブに沿って進む。',
      ],
    ),
  ];
}

SupportedTaskTemplate? supportedTaskTemplateById(String id) {
  for (final template in buildSupportedTaskTemplates()) {
    if (template.task.id == id) {
      return template;
    }
  }
  return null;
}
