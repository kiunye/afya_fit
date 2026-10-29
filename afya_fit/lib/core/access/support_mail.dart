import 'package:afya_fit/core/access/access.dart';

/// Where "Contact us" goes. Override per build with
/// `--dart-define=SUPPORT_EMAIL=help@example.com`.
const supportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'kiunyearaya@gmail.com',
);

/// Opens a URI in another app (the mail app). Injected so tests can capture it.
typedef MailLauncher = Future<bool> Function(Uri uri);

/// Words for the features the API reports, as a person would say them.
String featureLabel(String? feature) {
  switch (feature) {
    case 'clients':
      return 'more clients';
    case 'nutrition_plans':
      return 'nutrition plans';
    case 'progress_analytics':
      return 'progress analytics';
    case 'progress_photos':
      return 'progress photos';
    case 'task_automation':
      return 'recurring tasks';
    case 'calendar':
      return 'the calendar';
    case 'read_only':
      return 'editing';
    default:
      return 'this feature';
  }
}

/// The pre-filled message for "Contact us": what the person wanted, on which
/// plan, and from which account, so support can reply without asking.
Uri supportMailto({
  required String feature,
  required Access access,
  String? requiredTier,
  String? accountEmail,
}) {
  final subject = 'Upgrade request: ${featureLabel(feature)}';
  final body = [
    "Hello, I'd like ${featureLabel(feature)} on Afya Fit.",
    '',
    'Organisation: ${access.organizationName ?? 'unknown'}',
    'Current plan: ${access.tier}',
    if (requiredTier != null) 'Needs: $requiredTier',
    if (accountEmail != null) 'Account: $accountEmail',
  ].join('\n');

  // Build the query by hand: Uri.queryParameters turns spaces into "+", which
  // mail apps show literally.
  final query =
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
  return Uri(scheme: 'mailto', path: supportEmail, query: query);
}
