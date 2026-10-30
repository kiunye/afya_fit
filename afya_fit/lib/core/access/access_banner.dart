import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/access_provider.dart';

/// Wraps the whole app so the account banner sits above every screen.
class AccessShell extends ConsumerWidget {
  const AccessShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    if (!access.showsBanner) return child;

    return Column(
      children: [
        AccessBanner(access: access),
        Expanded(
          // The banner already clears the status bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// "Read-only until payment clears" or "Payment failed, full access until ...".
/// Owners are told to update payment; everyone else is told who can.
class AccessBanner extends StatelessWidget {
  const AccessBanner({super.key, required this.access});

  final Access access;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final readOnly = access.readOnly;
    final background = readOnly
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = readOnly
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                readOnly ? Icons.lock_outline : Icons.warning_amber_rounded,
                color: foreground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bannerMessage(access),
                  key: const Key('access-banner-text'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The banner's words, kept pure so they can be tested without a widget tree.
String bannerMessage(Access access) {
  final billing = access.billing;
  String date(DateTime? value) =>
      value == null ? '' : DateFormat('d MMM').format(value);

  final String lead;
  if (access.readOnly) {
    lead = switch (billing.reason) {
      'cancelled' => 'Read-only. The subscription was cancelled.',
      'expired' => 'Read-only. The subscription expired.',
      'inactive' => 'Read-only. This organisation is not active.',
      _ =>
        billing.since == null
            ? 'Read-only. Payment overdue.'
            : 'Read-only. Payment overdue since ${date(billing.since)}.',
    };
  } else {
    lead = billing.since == null
        ? 'Payment failed.'
        : 'Payment failed on ${date(billing.since)}.';
  }

  final detail = access.readOnly
      ? 'You can view everything; edits are paused.'
      : billing.until == null
      ? 'You keep full access for now.'
      : 'You keep full access until ${date(billing.until)}.';

  final who = access.canManageBilling
      ? 'Update payment to fix this.'
      : access.ownerName == null
      ? ''
      : '${access.ownerName} can fix this.';

  return [lead, detail, who].where((part) => part.isNotEmpty).join(' ');
}
