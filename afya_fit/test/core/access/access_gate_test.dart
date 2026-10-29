import 'package:flutter_test/flutter_test.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/access_gate.dart';

Access coach({
  int? clientLimit = 25,
  int clientCount = 0,
  bool nutrition = true,
  String billing = 'active',
}) => Access(
  tier: 'pro',
  clientLimit: clientLimit,
  clientCount: clientCount,
  permissions: {
    'client': {'list', 'read', 'create'},
    'nutrition_plan': {'list', 'read', 'create'},
    'progress_entry': {'list', 'read', 'analytics'},
  },
  features: {'nutrition_plans': nutrition, 'progress_analytics': nutrition},
  billing: Billing(
    state: billing,
    reason: billing == 'read_only' ? 'cancelled' : null,
  ),
);

void main() {
  test('an action the role may not attempt is forbidden', () {
    expect(
      checkGate(coach(), 'workout_plan', 'create').outcome,
      GateOutcome.forbidden,
    );
    expect(
      checkGate(Access.none, 'client', 'list').outcome,
      GateOutcome.forbidden,
    );
  });

  test('a permitted action on a healthy account is allowed', () {
    expect(checkGate(coach(), 'client', 'create').allowed, isTrue);
  });

  test('a read-only account blocks writes but not reads', () {
    final access = coach(billing: 'read_only');

    expect(checkGate(access, 'client', 'create').outcome, GateOutcome.readOnly);
    expect(checkGate(access, 'client', 'list').allowed, isTrue);
    expect(
      checkGate(
        access,
        'progress_entry',
        'analytics',
        feature: 'progress_analytics',
      ).allowed,
      isTrue,
    );
  });

  test('a closed Pro feature opens the upgrade prompt', () {
    final gate = checkGate(
      coach(nutrition: false),
      'nutrition_plan',
      'create',
      feature: 'nutrition_plans',
    );

    expect(gate.outcome, GateOutcome.upgrade);
    expect(gate.feature, 'nutrition_plans');
  });

  test('analytics are gated like any other Pro feature', () {
    final gate = checkGate(
      coach(nutrition: false),
      'progress_entry',
      'analytics',
      feature: 'progress_analytics',
    );

    expect(gate.outcome, GateOutcome.upgrade);
  });

  test('the client limit opens the upgrade prompt for adding a client', () {
    final gate = checkGate(
      coach(clientLimit: 3, clientCount: 3),
      'client',
      'create',
      countsAgainstClientLimit: true,
    );

    expect(gate.outcome, GateOutcome.upgrade);
    expect(gate.feature, 'clients');
  });

  test('below the limit, or without a limit, adding a client is allowed', () {
    expect(
      checkGate(
        coach(clientLimit: 3, clientCount: 2),
        'client',
        'create',
        countsAgainstClientLimit: true,
      ).allowed,
      isTrue,
    );
    expect(
      checkGate(
        coach(clientLimit: null, clientCount: 999),
        'client',
        'create',
        countsAgainstClientLimit: true,
      ).allowed,
      isTrue,
    );
  });

  test('read-only wins over the plan limit, so the reason is billing', () {
    final access = coach(clientLimit: 3, clientCount: 3, billing: 'read_only');

    expect(
      checkGate(
        access,
        'client',
        'create',
        countsAgainstClientLimit: true,
      ).outcome,
      GateOutcome.readOnly,
    );
  });
}
