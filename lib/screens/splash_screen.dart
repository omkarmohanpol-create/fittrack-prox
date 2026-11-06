import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), _continue);
  }

  void _continue() {
    if (!mounted) return;
    final signedIn = context.read<AuthProvider>().isAuthenticated;
    Navigator.of(context).pushReplacementNamed(signedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Train. Track. Improve.',
              style: TextStyle(fontSize: 16, color: context.muted),
            ),
          ],
        ),
      ),
    );
  }
}
