import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/access_provider.dart';
import 'package:afya_fit/features/auth/data/models/session.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';
import 'package:afya_fit/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a signed-out visitor sees the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => null as Session?),
          accessProvider.overrideWith((ref) => Access.none),
        ],
        child: const AfyaFitApp(),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Sign In'), findsOneWidget);
  });
}
