import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/location/course_location_setting.dart';
import 'package:xmu_rollcall/features/settings/course_locations_page.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '本人'),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scope in <int?>[null, 2]) {
    testWidgets(
      'unscheduled courses can configure a location for account $scope',
      (tester) async {
        await CourseCatalogStore.write(
          scope ?? 1,
          CourseCatalogSnapshot(
            fetchedAt: DateTime.now(),
            rolesResolved: true,
            termResolved: true,
            courses: [
              CatalogCourse(id: 'course-${scope ?? 1}', title: '未排课的课程'),
            ],
          ),
        );
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: CourseLocationsPage(assistUserId: scope),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('未排课的课程'), findsOneWidget);
        final setting = tester.widget<CourseLocationSetting>(
          find.byType(CourseLocationSetting),
        );
        expect(setting.courseId, 'course-${scope ?? 1}');
        expect(setting.assistUserId, scope);
        expect(find.text('选择上课地点'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
