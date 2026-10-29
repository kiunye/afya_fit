import 'package:flutter/foundation.dart';

/// Whether the organization may write data right now, and why. Mirrors the
/// `entitlements.billing` object the API sends.
@immutable
class Billing {
  const Billing({this.state = 'active', this.reason, this.since, this.until});

  /// `active` or `read_only`.
  final String state;

  /// `grace`, `cancelling`, `past_due`, `cancelled`, `expired`, `inactive`, or
  /// null when billing is healthy.
  final String? reason;

  /// When the problem started (the end of the last paid period).
  final DateTime? since;

  /// The last moment of full access, for `grace` and `cancelling`.
  final DateTime? until;

  factory Billing.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Billing();
    return Billing(
      state: json['state'] as String? ?? 'active',
      reason: json['reason'] as String?,
      since: _date(json['since']),
      until: _date(json['until']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

/// What the signed-in user can do, as decided by the server.
///
/// The app asks `can('client', 'create')`, never "am I a trainer?". The server
/// still enforces every rule per record, so this only decides what to show.
@immutable
class Access {
  const Access({
    required this.permissions,
    required this.tier,
    this.clientLimit,
    this.clientCount = 0,
    this.features = const {},
    this.billing = const Billing(),
    this.organizationName,
    this.ownerName,
  });

  /// Nothing is allowed: used while signed out or when the session is unknown.
  static const Access none = Access(permissions: {}, tier: 'free');

  /// resource => actions the role may attempt, e.g. `client` => `{list, create}`.
  final Map<String, Set<String>> permissions;

  final String tier;

  /// `null` means unlimited.
  final int? clientLimit;
  final int clientCount;

  /// Pro features that are switched on, e.g. `nutrition_plans`.
  final Map<String, bool> features;

  final Billing billing;
  final String? organizationName;

  /// Who to ask about upgrading.
  final String? ownerName;

  factory Access.fromJson(Map<String, dynamic> json) {
    final permissions = <String, Set<String>>{};
    (json['permissions'] as Map<String, dynamic>? ?? {}).forEach((
      resource,
      actions,
    ) {
      permissions[resource] = {
        for (final a in actions as List<dynamic>) a as String,
      };
    });

    final entitlements = json['entitlements'] as Map<String, dynamic>? ?? {};
    final organization = json['organization'] as Map<String, dynamic>? ?? {};

    return Access(
      permissions: permissions,
      tier: entitlements['tier'] as String? ?? 'free',
      clientLimit: entitlements['client_limit'] as int?,
      clientCount: entitlements['client_count'] as int? ?? 0,
      features: {
        for (final e
            in (entitlements['features'] as Map<String, dynamic>? ?? {})
                .entries)
          e.key: e.value == true,
      },
      billing: Billing.fromJson(
        entitlements['billing'] as Map<String, dynamic>?,
      ),
      organizationName: organization['name'] as String?,
      ownerName: organization['owner_name'] as String?,
    );
  }

  bool can(String resource, String action) =>
      permissions[resource]?.contains(action) ?? false;

  bool featureOn(String feature) => features[feature] ?? false;

  /// A trainer or organization owner (anyone who can list clients).
  bool get isCoach => can('client', 'list');

  /// A client using their own data.
  bool get isClient => !isCoach && can('client_workout', 'list');

  bool get isPlatformAdmin => can('admin_panel', 'access');

  bool get canManageBilling => can('subscription', 'manage');

  /// Coaches cannot write while the organization is read-only. Clients keep
  /// using their own data.
  bool get readOnly => isCoach && billing.state == 'read_only';

  bool get inGrace => isCoach && billing.reason == 'grace';

  bool get atClientLimit => clientLimit != null && clientCount >= clientLimit!;

  /// Whether to show the account banner: only coaches, and not platform admins.
  bool get showsBanner => isCoach && !isPlatformAdmin && (readOnly || inGrace);
}
