import 'package:flutter_test/flutter_test.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/support_mail.dart';

void main() {
  const access = Access(
    permissions: {},
    tier: 'free',
    organizationName: 'Njoroge Strength',
    ownerName: 'Wanjiru Njoroge',
  );

  group('supportMailto', () {
    final uri = supportMailto(
      feature: 'nutrition_plans',
      access: access,
      requiredTier: 'pro',
      accountEmail: 'brian@example.com',
    );

    test('is a mailto link to the support address', () {
      expect(uri.scheme, 'mailto');
      expect(uri.path, supportEmail);
    });

    test('names the feature in the subject', () {
      expect(
        Uri.decodeComponent(uri.query),
        contains('subject=Upgrade request: nutrition plans'),
      );
    });

    test('tells support who is asking and what plan they are on', () {
      final text = Uri.decodeComponent(uri.query);

      expect(text, contains('Organisation: Njoroge Strength'));
      expect(text, contains('Current plan: free'));
      expect(text, contains('Needs: pro'));
      expect(text, contains('Account: brian@example.com'));
    });

    test(
      'encodes spaces as %20, not "+", so mail apps show them correctly',
      () {
        expect(uri.query, isNot(contains('+')));
        expect(uri.query, contains('Upgrade%20request'));
      },
    );
  });

  test('leaves out what it does not know', () {
    final text = Uri.decodeComponent(
      supportMailto(feature: 'clients', access: Access.none).query,
    );

    expect(text, contains('Organisation: unknown'));
    expect(text, isNot(contains('Needs:')));
    expect(text, isNot(contains('Account:')));
  });

  test('featureLabel speaks plainly', () {
    expect(featureLabel('clients'), 'more clients');
    expect(featureLabel('progress_photos'), 'progress photos');
    expect(featureLabel('read_only'), 'editing');
    expect(featureLabel('something_new'), 'this feature');
    expect(featureLabel(null), 'this feature');
  });
}
