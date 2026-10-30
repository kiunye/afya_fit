import 'package:flutter_test/flutter_test.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/plan_block.dart';

void main() {
  const free = Access(
    permissions: {},
    tier: 'free',
    clientLimit: 3,
    organizationName: 'Njoroge Strength',
    ownerName: 'Wanjiru Njoroge',
  );

  test('label speaks plainly', () {
    expect(const PlanBlock('clients').label, 'more clients');
    expect(const PlanBlock('progress_photos').label, 'progress photos');
    expect(const PlanBlock.readOnly().label, 'editing');
    expect(const PlanBlock('something_new').label, 'this feature');
  });

  group('title and message', () {
    test('a closed feature names the tier it needs', () {
      const block = PlanBlock('nutrition_plans', requiredTier: 'pro');

      expect(block.title, 'Nutrition plans are on Pro');
      expect(block.message(free), contains('Nutrition plans need Pro'));
    });

    test('verbs agree with the feature', () {
      expect(const PlanBlock('calendar').title, 'The calendar is on Pro');
      expect(
        const PlanBlock('progress_photos').title,
        'Progress photos are on Pro',
      );
    });

    test('the client limit says how many fit', () {
      const block = PlanBlock(PlanBlock.clientsFeature);

      expect(block.title, 'Client limit reached');
      expect(block.message(free), contains('room for 3 clients'));
    });

    test('read-only is about payment, not plans', () {
      const block = PlanBlock.readOnly();

      expect(block.title, 'Account is read-only');
      expect(block.message(free), contains('Payment is overdue'));
    });
  });

  group('askOwner', () {
    test('points people who cannot fix it at the owner', () {
      expect(
        const PlanBlock('calendar').askOwner(free),
        'Ask Wanjiru Njoroge (owner) to upgrade.',
      );
      expect(
        const PlanBlock.readOnly().askOwner(free),
        'Ask Wanjiru Njoroge (owner) to update payment.',
      );
    });

    test('is silent for the owner, or when the owner is unknown', () {
      const owner = Access(
        permissions: {
          'subscription': {'manage'},
        },
        tier: 'free',
        ownerName: 'Wanjiru Njoroge',
      );

      expect(const PlanBlock('calendar').askOwner(owner), isNull);
      expect(const PlanBlock('calendar').askOwner(Access.none), isNull);
    });
  });
}
