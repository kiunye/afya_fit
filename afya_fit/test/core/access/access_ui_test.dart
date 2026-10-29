import 'dart:convert';

import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/access_banner.dart';
import 'package:afya_fit/core/access/access_provider.dart';
import 'package:afya_fit/core/access/upgrade_sheet.dart';
import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/routing/role_router.dart';
import 'package:afya_fit/features/auth/data/models/session.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Access coach({
  Billing billing = const Billing(state: 'active'),
  bool owner = false,
}) => Access(
  tier: 'free',
  clientLimit: 3,
  organizationName: 'Njoroge Strength',
  ownerName: 'Wanjiru Njoroge',
  permissions: {
    'client': {'list', 'read', 'create'},
    if (owner) 'subscription': {'read', 'manage'},
  },
  billing: billing,
);

Widget host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('bannerMessage', () {
    test('read-only names the reason and who can fix it', () {
      final text = bannerMessage(
        coach(billing: const Billing(state: 'read_only', reason: 'cancelled')),
      );

      expect(text, contains('subscription was cancelled'));
      expect(text, contains('edits are paused'));
      expect(text, contains('Wanjiru Njoroge can fix this'));
    });

    test('owners are told to update payment', () {
      final text = bannerMessage(
        coach(
          owner: true,
          billing: const Billing(state: 'read_only', reason: 'expired'),
        ),
      );

      expect(text, contains('expired'));
      expect(text, contains('Update payment'));
    });

    test('grace keeps access and says until when', () {
      final text = bannerMessage(
        coach(
          billing: Billing(
            state: 'active',
            reason: 'grace',
            since: DateTime.utc(2026, 10, 9),
            until: DateTime.utc(2026, 10, 16),
          ),
        ),
      );

      expect(text, contains('Payment failed on 9 Oct'));
      expect(text, contains('full access until 16 Oct'));
    });
  });

  group('AccessShell', () {
    testWidgets('shows no banner on a healthy account', (tester) async {
      await tester.pumpWidget(
        host(
          const AccessShell(child: Text('home')),
          overrides: [accessProvider.overrideWith((ref) => coach())],
        ),
      );
      await tester.pump();

      expect(find.text('home'), findsOneWidget);
      expect(find.byKey(const Key('access-banner-text')), findsNothing);
    });

    testWidgets('shows the banner above the app when read-only', (tester) async {
      await tester.pumpWidget(
        host(
          const AccessShell(child: Text('home')),
          overrides: [
            accessProvider.overrideWith(
              (ref) => coach(
                billing: const Billing(state: 'read_only', reason: 'cancelled'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('home'), findsOneWidget);
      expect(find.byKey(const Key('access-banner-text')), findsOneWidget);
    });
  });

  group('UpgradeSheet', () {
    Future<List<Uri>> openContact(
      WidgetTester tester,
      UpgradeDetails details,
      Access access,
    ) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        host(
          UpgradeSheet(details: details),
          overrides: [
            accessProvider.overrideWith((ref) => access),
            sessionProvider.overrideWith((ref) async => null as Session?),
            mailLauncherProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('contact-us')));
      await tester.pump();
      return opened;
    }

    testWidgets('Contact us opens a mailto naming the feature', (tester) async {
      final opened = await openContact(
        tester,
        const UpgradeDetails(feature: 'nutrition_plans', requiredTier: 'pro'),
        coach(),
      );

      expect(opened, hasLength(1));
      expect(opened.single.scheme, 'mailto');
      expect(
        Uri.decodeComponent(opened.single.query),
        contains('Njoroge Strength'),
      );
    });

    testWidgets('non-owners are told who to ask', (tester) async {
      await openContact(
        tester,
        const UpgradeDetails(feature: 'clients'),
        coach(),
      );

      expect(find.byKey(const Key('ask-owner')), findsOneWidget);
      expect(find.textContaining('Wanjiru Njoroge'), findsWidgets);
    });

    testWidgets('owners are not sent to someone else', (tester) async {
      await openContact(
        tester,
        const UpgradeDetails(feature: 'clients'),
        coach(owner: true),
      );

      expect(find.byKey(const Key('ask-owner')), findsNothing);
    });

    testWidgets('falls back to a snackbar when no mail app opens', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const UpgradeSheet(details: UpgradeDetails(feature: 'clients')),
          overrides: [
            accessProvider.overrideWith((ref) => coach()),
            sessionProvider.overrideWith((ref) async => null as Session?),
            mailLauncherProvider.overrideWithValue((uri) async => false),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('contact-us')));
      await tester.pump();

      expect(find.textContaining('No mail app found'), findsOneWidget);
    });
  });

  group('UpgradeDetails.fromException', () {
    test('reads the feature and tier of an upgrade_required body', () {
      final details = UpgradeDetails.fromException(
        ApiException(
          statusCode: 402,
          message: 'upgrade_required',
          body: {
            'error': 'upgrade_required',
            'feature': 'nutrition_plans',
            'required_tier': 'pro',
          },
        ),
      );

      expect(details.feature, 'nutrition_plans');
      expect(details.requiredTier, 'pro');
      expect(details.readOnly, isFalse);
    });

    test('subscription_inactive means read-only', () {
      final details = UpgradeDetails.fromException(
        ApiException(
          statusCode: 402,
          message: 'subscription_inactive',
          body: {'error': 'subscription_inactive'},
        ),
      );

      expect(details.readOnly, isTrue);
    });

    test('a body that is not JSON still gives a usable prompt', () {
      final details = UpgradeDetails.fromException(
        ApiException(statusCode: 402, message: 'An error occurred'),
      );

      expect(details.feature, 'unknown');
    });
  });

  group('RoleRouter.homeKindFor', () {
    test('picks the home screen from permissions', () {
      expect(RoleRouter.homeKindFor(coach()), HomeKind.coach);
      expect(
        RoleRouter.homeKindFor(
          const Access(
            tier: 'free',
            permissions: {
              'client_workout': {'list'},
            },
          ),
        ),
        HomeKind.client,
      );
      expect(
        RoleRouter.homeKindFor(
          const Access(
            tier: 'free',
            permissions: {
              'admin_panel': {'access'},
            },
          ),
        ),
        HomeKind.platform,
      );
    });
  });

  group('ApiClient keeps the error body', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a 402 exposes its JSON', () async {
      final client = ApiClient(
        baseUrl: 'http://test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'upgrade_required', 'feature': 'clients'}),
            402,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        client.get('/clients'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isPaymentRequired, 'isPaymentRequired', isTrue)
              .having((e) => e.body?['feature'], 'feature', 'clients'),
        ),
      );
    });

    test('a non-JSON error has a null body', () async {
      final client = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response('<html>', 500)),
      );

      await expectLater(
        client.get('/clients'),
        throwsA(
          isA<ApiException>().having((e) => e.body, 'body', isNull),
        ),
      );
    });
  });
}
