import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('release past threshold triggers onRefresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      wrap(
        AppPullToRefresh(
          threshold: 72,
          onRefresh: () async {
            refreshed++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200, child: Text('empty')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // dragRate 0.5 → need ~144px finger travel to arm at threshold 72
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump();

    final state = tester.state<AppPullToRefreshState>(
      find.byType(AppPullToRefresh),
    );
    expect(state.status, AppPullToRefreshStatus.armed);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(refreshed, 1);
    expect(state.status, AppPullToRefreshStatus.idle);
  });

  testWidgets('arm then reverse below threshold cancels', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      wrap(
        AppPullToRefresh(
          threshold: 72,
          onRefresh: () async {
            refreshed++;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200, child: Text('empty')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(ListView));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump();

    final state = tester.state<AppPullToRefreshState>(
      find.byType(AppPullToRefresh),
    );
    expect(state.status, AppPullToRefreshStatus.armed);

    // Reverse past threshold (finger back up) without releasing.
    await gesture.moveBy(const Offset(0, -180));
    await tester.pump();
    expect(state.pullDistance, lessThan(72));
    expect(state.status, isNot(AppPullToRefreshStatus.armed));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(refreshed, 0);
    expect(state.status, AppPullToRefreshStatus.idle);
  });

  testWidgets('release before threshold does not refresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      wrap(
        AppPullToRefresh(
          threshold: 72,
          onRefresh: () async {
            refreshed++;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200, child: Text('empty')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, 60)); // 60 * 0.5 = 30 < 72
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(refreshed, 0);
  });
}
