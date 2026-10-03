import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../providers/auth_service.dart';
import '../theme/app_theme.dart';

import 'admin_main_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _checkedUserId;
  Future<bool>? _staffFuture;

  void _prepareStaffCheck(String userId) {
    if (_checkedUserId == userId && _staffFuture != null) {
      return;
    }

    _checkedUserId = userId;

    _staffFuture = context.read<AdminProvider>().isStaff(refresh: true);
  }

  void _retry() {
    final userId = context.read<AuthService>().user?.id;

    if (userId == null) {
      return;
    }

    setState(() {
      _checkedUserId = userId;

      _staffFuture = context.read<AdminProvider>().isStaff(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isAuthenticated || auth.user == null) {
      _checkedUserId = null;
      _staffFuture = null;

      return const LoginScreen();
    }

    _prepareStaffCheck(auth.user!.id);

    return FutureBuilder<bool>(
      future: _staffFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.hasError) {
          return _AuthErrorScreen(onRetry: _retry);
        }

        final isStaff = snapshot.data == true;

        if (isStaff) {
          return const AdminMainScreen();
        }

        return const MainScreen();
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/University_of_Mindanao_Logo.png',
              height: 82,
            ),
            const SizedBox(height: 22),
            CircularProgressIndicator(color: AppColors.brandOf(context)),
            const SizedBox(height: 14),
            Text(
              'Loading your account...',
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _AuthErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 58,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not verify account access',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maroon,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
