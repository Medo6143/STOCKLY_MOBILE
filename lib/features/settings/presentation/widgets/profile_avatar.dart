import 'package:flutter/material.dart';
import 'package:stockly/core/text/initials.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// The user's initials (Arabic or Latin) in a circle inside a mint
/// gradient ring (design-refresh brief). A name without letters shows a
/// person icon.
class ProfileAvatar extends StatelessWidget {
  const new({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final initials = initialsOf(name);
    final size = spacing.huge + spacing.xxl;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsetsDirectional.all(spacing.xxs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [colors.mint, colors.mintSoft],
        ),
      ),
      child: Container(
        padding: EdgeInsetsDirectional.all(spacing.xxs),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.heroEnd,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.mintSoft,
          ),
          child: Center(
            child: initials.isEmpty
                ? Icon(Icons.person_rounded, color: colors.ink)
                : Text(
                    initials,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: colors.ink),
                  ),
          ),
        ),
      ),
    );
  }
}
