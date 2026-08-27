import 'package:flutter_test/flutter_test.dart';
import 'package:skate_dataset_studio/features/tasks/domain/supported_task_templates.dart';

void main() {
  test('provides exactly the three supported practice tasks', () {
    final templates = buildSupportedTaskTemplates(createdAtMs: 1000);

    expect(templates, hasLength(3));
    expect(
      templates.map((template) => template.task.id).toSet(),
      supportedTaskIds,
    );
    for (final template in templates) {
      expect(template.task.validate(), isEmpty, reason: template.task.id);
    }
  });

  test('keeps the pictured forward-change edge orders', () {
    final templates = buildSupportedTaskTemplates(createdAtMs: 1000);
    final byId = {
      for (final template in templates) template.task.id: template.task,
    };

    expect(
      byId['forward-change-half-circle-right']!.segments.map(
        (segment) => segment.expectedEdge.notation,
      ),
      ['RFO', 'RFI', 'LFI', 'LFO', 'RFO', 'RFI', 'LFI', 'LFO'],
    );
    expect(
      byId['forward-change-half-circle-left']!.segments.map(
        (segment) => segment.expectedEdge.notation,
      ),
      ['LFO', 'LFI', 'RFI', 'RFO', 'LFO', 'LFI', 'RFI', 'RFO'],
    );
  });

  test('makes the waltz three turn explicit at count three', () {
    final template = supportedTaskTemplateById('waltz-three-step')!;

    expect(template.task.segments.first.id, 'rfo-count-1-to-3');
    expect(template.task.segments[1].id, 'rbo-after-three-turn');
    expect(
      template.task.segments
          .take(2)
          .map((segment) => segment.expectedEdge.notation),
      ['RFO', 'RBO'],
    );
  });
}
