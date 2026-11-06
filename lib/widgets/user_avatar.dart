import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/theme.dart';

/// The profile picture, or the user's initial when there is none (or it
/// fails to load).
class UserAvatar extends StatelessWidget {
  final double radius;

  const UserAvatar({super.key, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final url = auth.avatarUrl;
    final initial = Text(
      auth.initial,
      style: TextStyle(
        fontSize: radius * 0.8,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: url == null
          ? initial
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => initial,
              ),
            ),
    );
  }
}
