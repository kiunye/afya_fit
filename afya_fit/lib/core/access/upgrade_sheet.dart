import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/access_provider.dart';
import 'package:afya_fit/core/access/plan_block.dart';
import 'package:afya_fit/core/access/support_mail.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';

Future<void> showUpgradeSheet(BuildContext context, PlanBlock block) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UpgradeSheet(block: block),
  );
}

/// Explains a plan block and offers to email us. Owners are pointed at the
/// upgrade; everyone else is told who to ask.
class UpgradeSheet extends ConsumerWidget {
  const UpgradeSheet({super.key, required this.block});

  final PlanBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    final email = ref.watch(sessionProvider).value?.user.email;
    final textTheme = Theme.of(context).textTheme;
    final askOwner = block.askOwner(access);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.title, style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(block.message(access), style: textTheme.bodyLarge),
            if (askOwner != null) ...[
              const SizedBox(height: 12),
              Text(
                askOwner,
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

  Future<void> _contact(
    BuildContext context,
    WidgetRef ref,
    Access access,
    String? email,
  ) async {
    final uri = supportMailto(
      block: block,
      access: access,
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
}
