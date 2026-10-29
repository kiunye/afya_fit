import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/support_mail.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';

/// What the signed-in user can do. [Access.none] while signed out or unknown.
/// Invalidate [sessionProvider] to refresh it (after a 402, login or logout).
final accessProvider = FutureProvider<Access>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  return session?.access ?? Access.none;
});

/// Opens the mail app. Override in tests to capture the link.
final mailLauncherProvider = Provider<MailLauncher>((ref) {
  return (uri) => launchUrl(uri);
});
