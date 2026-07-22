import 'package:flutter/material.dart';

import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';

import '../domain/account.dart';

Color _colorForAccount(Account account) {
  // Stable-ish accent per account id; avoids importing more deps.
  final id = account.id;
  var hash = 0;
  for (final cu in id.codeUnits) {
    hash = 0x1fffffff & (hash + cu);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= (hash >> 6);
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= (hash >> 11);
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));

  final palette = Colors.primaries;
  return palette[hash.abs() % palette.length].shade600;
}

String _initialForAccount(Account account) {
  final name = account.name.trim();
  if (name.isEmpty) return '?';
  return name.characters.first.toUpperCase();
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.account,
    this.radius = 18,
    this.showTypeBadge = false,
  });

  final Account account;
  final double radius;
  final bool showTypeBadge;

  IconData _typeIcon(AccountType type) => switch (type) {
    AccountType.local => FleurIcons.localAccount,
    AccountType.miniflux => FleurIcons.minifluxAccount,
    AccountType.fever => FleurIcons.feverAccount,
    AccountType.googleReader => FleurIcons.googleReaderAccount,
  };

  @override
  Widget build(BuildContext context) {
    final bg = _colorForAccount(account);
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      child: Text(
        _initialForAccount(account),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.9),
      ),
    );

    if (!showTypeBadge) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).fleurSurface.floating,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  blurRadius: 6,
                  color: Color(0x33000000),
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(_typeIcon(account.type), size: radius * 0.65),
          ),
        ),
      ],
    );
  }
}
