import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/campus/campus_search_index.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/lifestyle/life_services_page.dart';

void main() {
  testWidgets('directory and search share the native life services entry', (
    tester,
  ) async {
    final tool = campusTools.singleWhere((t) => t.id == 'life-services');
    final entry = campusSearchFeatures(
      null,
    ).singleWhere((e) => e.title == '生活服务');
    expect(tool.trailing, isA<LifeServiceBalancesTrailing>());
    expect(entry.url, isNull);
    expect(campusSearchMatches('小灵龙', entry.keywords), isTrue);
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox()),
    );
    final context = tester.element(find.byType(SizedBox));
    expect(tool.page(context), isA<LifeServicesPage>());
    expect(entry.page!(context), isA<LifeServicesPage>());
  });
}
