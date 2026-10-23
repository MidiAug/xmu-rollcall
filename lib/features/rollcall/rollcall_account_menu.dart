import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

class RollcallAccountMenu extends StatelessWidget {
  const RollcallAccountMenu({
    super.key,
    required this.value,
    required this.identities,
    required this.ownerName,
    required this.onChanged,
    this.width = 180,
  });
  final int value;
  final List<AssistIdentity> identities;
  final String ownerName;
  final ValueChanged<int> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: AppShellSelect<int>(
      key: const ValueKey('rollcall-identity-menu'),
      width: width,
      menuWidth: 220,
      value: value,
      items: [0, for (final identity in identities) identity.userId],
      labelOf: (id) => id == 0
          ? ownerName
          : identities.firstWhere((item) => item.userId == id).displayName,
      leading: Icon(
        Icons.person_outline_rounded,
        size: 18,
        color: AppPalette.of(context).primary,
      ),
      onChanged: identities.isEmpty
          ? null
          : (id) {
              if (id != value) onChanged(id);
            },
    ),
  );
}
