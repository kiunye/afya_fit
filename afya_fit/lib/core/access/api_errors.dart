import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/access/access_gate.dart';
import 'package:afya_fit/core/access/access_provider.dart';
import 'package:afya_fit/core/access/plan_block.dart';
import 'package:afya_fit/core/access/upgrade_sheet.dart';
import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';

/// Shows what went wrong with an API call. A 402 (plan limit or read-only) opens
/// the upgrade sheet and refreshes what the app knows about the account; any
/// other error is a snackbar.
Future<void> showApiError(
  BuildContext context,
  WidgetRef ref,
  Object error,
) async {
  if (error is ApiException && error.isPaymentRequired) {
    ref.invalidate(sessionProvider);
    if (context.mounted) {
      await showUpgradeSheet(context, PlanBlock.fromException(error));
    }
    return;
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
  );
}

/// Runs [onAllowed] if the gate lets the action through, and otherwise explains
/// why: an upgrade sheet for a plan limit, a snackbar for read-only or no access.
/// Used for taps on write controls so a blocked action never reaches the server.
Future<void> runGated(
  BuildContext context,
  WidgetRef ref, {
  required String resource,
  required String action,
  required VoidCallback onAllowed,
  String? feature,
  bool countsAgainstClientLimit = false,
}) async {
  final access = ref.read(accessProvider);
  final gate = checkGate(
    access,
    resource,
    action,
    feature: feature,
    countsAgainstClientLimit: countsAgainstClientLimit,
  );

  switch (gate.outcome) {
    case GateOutcome.allowed:
      onAllowed();
    case GateOutcome.upgrade:
      await showUpgradeSheet(
        context,
        PlanBlock(gate.feature ?? 'unknown', requiredTier: 'pro'),
      );
    case GateOutcome.readOnly:
      await showUpgradeSheet(context, const PlanBlock.readOnly());
    case GateOutcome.forbidden:
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have access to that.')),
        );
      }
  }
}
