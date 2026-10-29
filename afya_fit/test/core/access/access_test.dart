import 'package:flutter_test/flutter_test.dart';
import 'package:afya_fit/core/access/access.dart';

Map<String, dynamic> payload({
  Map<String, dynamic>? permissions,
  String tier = 'pro',
  int? clientLimit = 25,
  int clientCount = 2,
  Map<String, dynamic>? billing,
}) => {
  'permissions':
      permissions ??
      {
        'client': ['list', 'read', 'create'],
        'workout_plan': ['list', 'read'],
      },
  'entitlements': {
    'tier': tier,
    'client_limit': clientLimit,
    'client_count': clientCount,
    'features': {'nutrition_plans': true, 'calendar': false},
    'billing':
        billing ??
        {'state': 'active', 'reason': null, 'since': null, 'until': null},
  },
  'organization': {'name': 'Njoroge Strength', 'owner_name': 'Wanjiru Njoroge'},
};

void main() {
  group('Access.fromJson', () {
    test('reads permissions, entitlements and the organisation', () {
      final access = Access.fromJson(payload());

      expect(access.can('client', 'create'), isTrue);
      expect(access.can('client', 'delete'), isFalse);
      expect(access.can('subscription', 'manage'), isFalse);
      expect(access.tier, 'pro');
      expect(access.clientLimit, 25);
      expect(access.clientCount, 2);
      expect(access.featureOn('nutrition_plans'), isTrue);
      expect(access.featureOn('calendar'), isFalse);
      expect(access.featureOn('unknown'), isFalse);
      expect(access.organizationName, 'Njoroge Strength');
      expect(access.ownerName, 'Wanjiru Njoroge');
    });

    test('a null client limit means unlimited', () {
      final access = Access.fromJson(
        payload(clientLimit: null, clientCount: 10000),
      );

      expect(access.clientLimit, isNull);
      expect(access.atClientLimit, isFalse);
    });

    test('tolerates missing sections', () {
      final access = Access.fromJson({});

      expect(access.permissions, isEmpty);
      expect(access.tier, 'free');
      expect(access.billing.state, 'active');
    });
  });

  group('roles are derived from permissions', () {
    test(
      'a coach can list clients; a client can list their own workouts only',
      () {
        final coach = Access.fromJson(payload());
        final client = Access.fromJson(
          payload(
            permissions: {
              'client_workout': ['list', 'read', 'complete'],
            },
          ),
        );

        expect(coach.isCoach, isTrue);
        expect(coach.isClient, isFalse);
        expect(client.isCoach, isFalse);
        expect(client.isClient, isTrue);
      },
    );

    test('a platform admin is recognised by the admin panel permission', () {
      final admin = Access.fromJson(
        payload(
          permissions: {
            'client': ['list', 'read'],
            'admin_panel': ['access'],
          },
        ),
      );

      expect(admin.isPlatformAdmin, isTrue);
      expect(admin.showsBanner, isFalse);
    });

    test('billing management is its own permission', () {
      final owner = Access.fromJson(
        payload(
          permissions: {
            'client': ['list'],
            'subscription': ['read', 'manage'],
          },
        ),
      );

      expect(owner.canManageBilling, isTrue);
      expect(Access.fromJson(payload()).canManageBilling, isFalse);
    });
  });

  group('billing state', () {
    test('read-only blocks coaches and shows the banner', () {
      final access = Access.fromJson(
        payload(billing: {'state': 'read_only', 'reason': 'cancelled'}),
      );

      expect(access.readOnly, isTrue);
      expect(access.inGrace, isFalse);
      expect(access.showsBanner, isTrue);
    });

    test('the grace period keeps access and shows the banner', () {
      final access = Access.fromJson(
        payload(
          billing: {
            'state': 'active',
            'reason': 'grace',
            'since': '2026-10-09T00:00:00Z',
            'until': '2026-10-16T00:00:00Z',
          },
        ),
      );

      expect(access.readOnly, isFalse);
      expect(access.inGrace, isTrue);
      expect(access.showsBanner, isTrue);
      expect(access.billing.until, isNotNull);
    });

    test('clients never see read-only or the banner', () {
      final client = Access.fromJson(
        payload(
          permissions: {
            'client_workout': ['list'],
          },
          billing: {'state': 'read_only', 'reason': 'cancelled'},
        ),
      );

      expect(client.readOnly, isFalse);
      expect(client.showsBanner, isFalse);
    });

    test('healthy billing shows nothing', () {
      expect(Access.fromJson(payload()).showsBanner, isFalse);
    });
  });

  test('atClientLimit is true when the count reaches the limit', () {
    expect(
      Access.fromJson(payload(clientLimit: 3, clientCount: 2)).atClientLimit,
      isFalse,
    );
    expect(
      Access.fromJson(payload(clientLimit: 3, clientCount: 3)).atClientLimit,
      isTrue,
    );
  });

  test('Access.none allows nothing', () {
    expect(Access.none.can('client', 'list'), isFalse);
    expect(Access.none.isCoach, isFalse);
    expect(Access.none.showsBanner, isFalse);
  });
}
