import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/api/api_client.dart';

/// Why an action was blocked, and every word the app says about it: the upgrade
/// sheet and the pre-filled support email both read from here.
class PlanBlock {
  const PlanBlock(this.feature, {this.requiredTier});

  /// The account is read-only, so nothing can be edited.
  const PlanBlock.readOnly() : this(readOnlyFeature);

  /// From the API's 402 body: `{"error": "upgrade_required", "feature": ...}` or
  /// `{"error": "subscription_inactive", ...}`.
  factory PlanBlock.fromException(ApiException error) {
    final body = error.body ?? const {};
    if (body['error'] == 'subscription_inactive') {
      return const PlanBlock.readOnly();
    }
    return PlanBlock(
      body['feature'] as String? ?? 'unknown',
      requiredTier: body['required_tier'] as String?,
    );
  }

  static const readOnlyFeature = 'read_only';

  /// The client limit, reported as a feature by the server and the gate.
  static const clientsFeature = 'clients';

  final String feature;
  final String? requiredTier;

  bool get isReadOnly => feature == readOnlyFeature;
  bool get isClientLimit => feature == clientsFeature;

  /// The feature as a person would say it, e.g. "nutrition plans".
  String get label => _features[feature]?.label ?? 'this feature';

  bool get _plural => _features[feature]?.plural ?? false;

  String get _tier => _capitalize(requiredTier ?? 'pro');

  String get title {
    if (isReadOnly) return 'Account is read-only';
    if (isClientLimit) return 'Client limit reached';
    return '${_capitalize(label)} ${_plural ? 'are' : 'is'} on $_tier';
  }

  String message(Access access) {
    if (isReadOnly) {
      return 'Payment is overdue, so edits are paused. You can still view everything.';
    }
    if (isClientLimit) {
      final limit = access.clientLimit;
      return '${access.organizationName ?? 'This organisation'} is on ${_capitalize(access.tier)}'
          '${limit == null ? '' : ', which has room for $limit clients'}. '
          'Add more by moving to $_tier.';
    }
    return 'Your organisation is on ${_capitalize(access.tier)}. '
        '${_capitalize(label)} ${_plural ? 'need' : 'needs'} $_tier.';
  }

  /// Who to ask, for people who cannot fix this themselves.
  String? askOwner(Access access) {
    if (access.canManageBilling || access.ownerName == null) return null;
    return 'Ask ${access.ownerName} (owner) to ${isReadOnly ? 'update payment' : 'upgrade'}.';
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

const _features = <String, ({String label, bool plural})>{
  'clients': (label: 'more clients', plural: true),
  'nutrition_plans': (label: 'nutrition plans', plural: true),
  'progress_analytics': (label: 'progress analytics', plural: false),
  'progress_photos': (label: 'progress photos', plural: true),
  'task_automation': (label: 'recurring tasks', plural: true),
  'calendar': (label: 'the calendar', plural: false),
  'read_only': (label: 'editing', plural: false),
};
