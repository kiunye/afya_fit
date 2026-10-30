import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/plan_block.dart';

/// Where "Contact us" goes. Override per build with
/// `--dart-define=SUPPORT_EMAIL=help@example.com`.
const supportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'kiunyearaya@gmail.com',
);

/// Opens a URI in another app (the mail app). Injected so tests can capture it.
typedef MailLauncher = Future<bool> Function(Uri uri);

/// The pre-filled message for "Contact us": what the person wanted, on which
/// plan, and from which account, so support can reply without asking.
Uri supportMailto({
  required PlanBlock block,
  required Access access,
  String? accountEmail,
}) {
  final subject = 'Upgrade request: ${block.label}';
  final body = [
    "Hello, I'd like ${block.label} on Afya Fit.",
    '',
    'Organisation: ${access.organizationName ?? 'unknown'}',
    'Current plan: ${access.tier}',
    if (block.requiredTier != null) 'Needs: ${block.requiredTier}',
    if (accountEmail != null) 'Account: $accountEmail',
  ].join('\n');

  // Build the query by hand: Uri.queryParameters turns spaces into "+", which
  // mail apps show literally.
  final query =
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
  return Uri(scheme: 'mailto', path: supportEmail, query: query);
}
