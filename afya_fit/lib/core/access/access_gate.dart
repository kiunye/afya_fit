import 'package:afya_fit/core/access/access.dart';

enum GateOutcome { allowed, forbidden, readOnly, upgrade }

/// What should happen when the user taps a write control.
class Gate {
  const Gate(this.outcome, {this.feature});

  final GateOutcome outcome;

  /// For [GateOutcome.upgrade]: the feature that is closed (`clients` for the
  /// client limit).
  final String? feature;

  bool get allowed => outcome == GateOutcome.allowed;
}

const _readActions = {'list', 'read', 'analytics'};

/// Decides, before any request is made, whether [action] on [resource] can go
/// ahead. [feature] is the Pro feature the action needs, if any;
/// [countsAgainstClientLimit] is true for adding a client.
///
/// The server decides for real; this only avoids a wasted request and lets the
/// app explain the block instead of showing an error.
Gate checkGate(
  Access access,
  String resource,
  String action, {
  String? feature,
  bool countsAgainstClientLimit = false,
}) {
  if (!access.can(resource, action)) return const Gate(GateOutcome.forbidden);

  if (!_readActions.contains(action) && access.readOnly) {
    return const Gate(GateOutcome.readOnly);
  }

  if (feature != null && !access.featureOn(feature)) {
    return Gate(GateOutcome.upgrade, feature: feature);
  }

  if (countsAgainstClientLimit && access.atClientLimit) {
    return const Gate(GateOutcome.upgrade, feature: 'clients');
  }

  return const Gate(GateOutcome.allowed);
}
