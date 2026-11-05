import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/location/campus_stories.dart';

void main() {
  test(
    'building profiles use a shared reading structure without editor notes',
    () {
      for (final story in [
        ...campusBuildingStories.values,
        ...campusGroupStories.values,
      ]) {
        final headings = story.sections.map((s) => s.title).toList();
        expect(headings.toSet().length, headings.length);
        expect(
          headings.every(const {'沿革与命名', '建筑与空间', '学习与使用'}.contains),
          isTrue,
        );
        final content = [
          story.text,
          ...story.sections.map((s) => s.text),
        ].join('\n');
        for (final note in [
          '不应混作',
          '待进一步核实',
          '现有检索',
          '本目录沿用',
          '不能套用',
          '未确认捐建',
          '不用于推定',
          '不作为今天',
          '现目录',
          '此处只说明',
          '不代表现有',
          '不同时间节点',
          '不是建筑竣工',
          '不是建成年代',
          '不作为片区',
          '不沿用思明',
          '分属不同校区',
        ]) {
          expect(content, isNot(contains(note)), reason: story.url);
        }
      }
    },
  );
  test('Xiang’an pool introduces its own documented construction story', () {
    final pool = campusBuildingStories['xa-pool']!;
    final content = pool.sections.map((s) => s.text).join();
    expect(content, contains('2012年'));
    expect(content, contains('佘施淑好'));
    expect(pool.text, contains('佘明培'));
    expect(pool.text, isNot(contains('余明培')));
    expect(content, contains('太阳能'));
    expect(content, isNot(contains('明培体育馆')));
  });
}
