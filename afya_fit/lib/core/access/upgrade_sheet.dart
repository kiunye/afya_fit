import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/access_provider.dart';
import 'package:afya_fit/core/access/support_mail.dart';
import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';

/// Why an action was blocked, from a 402 response or a gate check.
class UpgradeDetails {
  const UpgradeDetails({
    required this.feature,
    this.requiredTier,
    this.readOnly = false,
  });

  /// The closed feature (`clients` for the client limit, `read_only` when the
  /// account is read-only).
  final String feature;
  final String? requiredTier;
  final bool readOnly;

  /// From the API's 402 body: `{"error": "upgrade_required", "feature": ...}` or
  /// `{"error": "subscription_inactive", ...}`.
  factory UpgradeDetails.fromException(ApiException error) {
    final body = error.body ?? const {};
    if (body['error'] == 'subscription_inactive') {
      return const UpgradeDetails(feature: 'read_only', readOnly: true);
    }
    return UpgradeDetails(
      feature: body['feature'] as String? ?? 'unknown',
      requiredTier: body['required_tier'] as String?,
    );
  }
}

Future<void> showUpgradeSheet(BuildContext context, UpgradeDetails details) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UpgradeSheet(details: details),
  );
}

/// Explains a plan block and offers to email us. Owners are pointed at the
/// upgrade; everyone else is told who to ask.
class UpgradeSheet extends ConsumerWidget {
  const UpgradeSheet({super.key, required this.details});

  final UpgradeDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider).value ?? Access.none;
    final email = ref.watch(sessionProvider).value?.user.email;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title(), style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(_message(access), style: textTheme.bodyLarge),
            if (!access.canManageBilling && access.ownerName != null) ...[
              const SizedBox(height: 12),
              Text(
                'Ask ${access.ownerName} (owner) to ${details.readOnly ? 'update payment' : 'upgrade'}.',
                key: const Key('ask-owner'),
                style: textTheme.titleSmall,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('contact-us'),
                onPressed: () => _contact(context, ref, access, email),
                child: const Text('Contact us'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title() {
    if (details.readOnly) return 'Account is read-only';
    if (details.feature == 'clients') return 'Client limit reached';
    return '${_capitalize(featureLabel(details.feature))} ${_isPlural() ? 'are' : 'is'} on ${_tier()}';
  }

  String _message(Access access) {
    if (details.readOnly) {
      return 'Payment is overdue, so edits are paused. You can still view everything.';
    }
    if (details.feature == 'clients') {
      final limit = access.clientLimit;
      return '${access.organizationName ?? 'This organisation'} is on ${_capitalize(access.tier)}'
          '${limit == null ? '' : ', which has room for $limit clients'}. '
          'Add more by moving to ${_tier()}.';
    }
    return 'Your organisation is on ${_capitalize(access.tier)}. '
        '${_capitalize(featureLabel(details.feature))} ${_isPlural() ? 'need' : 'needs'} ${_tier()}.';
  }

  String _tier() => _capitalize(details.requiredTier ?? 'pro');

  bool _isPlural() => const {'nutrition_plans'}.contains(details.feature);

  Future<void> _contact(
    BuildContext context,
    WidgetRef ref,
    Access access,
    String? email,
  ) async {
    final uri = supportMailto(
      feature: details.feature,
      access: access,
      requiredTier: details.requiredTier,
      accountEmail: email,
    );

    var opened = false;
    try {
      opened = await ref.read(mailLauncherProvider)(uri);
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No mail app found. Email $supportEmail instead.'),
        ),
      );
    }
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
