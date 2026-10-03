import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_service.dart';
import '../utils/error_messages.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  final _otpController = TextEditingController();

  final _newPasswordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  int _step = 0;

  bool _isLoading = false;

  bool _obscureNew = true;

  bool _obscureConfirm = true;

  static const int _cooldownDuration = 60;

  Timer? _cooldownTimer;

  int _cooldownSeconds = 0;

  bool get _onCooldown => _cooldownSeconds > 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();

    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();

    setState(() {
      _cooldownSeconds = _cooldownDuration;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _cooldownSeconds--;

        if (_cooldownSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp(AuthService authService) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_onCooldown) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.sendPasswordResetOtp(_emailController.text.trim());

      if (!mounted) return;

      setState(() {
        _step = 1;
      });

      _startCooldown();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reset code sent to '
            '${_emailController.text.trim()}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp(AuthService authService) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.verifyPasswordResetOtp(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePassword(AuthService authService) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.updatePassword(_newPasswordController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated! Please sign in.'),
          backgroundColor: Colors.green,
        ),
      );

      await authService.signOut();

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(key: _formKey, child: _buildStepContent(authService)),
        ),
      ),
    );
  }

  Widget _buildStepContent(AuthService authService) {
    if (_step == 0) {
      return _buildEmailStep(authService);
    }

    if (_step == 1) {
      return _buildOtpStep(authService);
    }

    return _buildPasswordStep(authService);
  }

  Widget _buildEmailStep(AuthService authService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_reset, size: 80, color: Color(0xFF800000)),

        const SizedBox(height: 16),

        const Text(
          'Forgot your password?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          'Enter your account email '
          'and we\'ll send you a reset code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),

        const SizedBox(height: 24),

        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !_isLoading,
          onFieldSubmitted: (_) => _sendOtp(authService),
          decoration: const InputDecoration(
            labelText: 'Account Email',
            hintText: 'UM email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final email = value?.trim().toLowerCase() ?? '';

            if (email.isEmpty) {
              return 'Please enter your email';
            }

            if (!authService.isAllowedLoginEmail(email)) {
              return 'Use your UM email or authorized admin account';
            }

            return null;
          },
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: (_isLoading || _onCooldown)
                ? null
                : () => _sendOtp(authService),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    _onCooldown
                        ? 'Wait ${_cooldownSeconds}s'
                        : 'Send Reset Code',
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(AuthService authService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: Color(0xFF800000),
        ),

        const SizedBox(height: 16),

        const Text(
          'Enter the reset code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          'We sent a code to '
          '${_emailController.text.trim()}',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          enabled: !_isLoading,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _verifyOtp(authService),
          decoration: const InputDecoration(
            labelText: '6-digit code',
            prefixIcon: Icon(Icons.pin_outlined),
            border: OutlineInputBorder(),
            counterText: '',
          ),
          validator: (value) {
            if (value == null || value.length != 6) {
              return 'Enter the 6-digit code';
            }

            if (!RegExp(r'^\d{6}$').hasMatch(value)) {
              return 'Code must be 6 digits';
            }

            return null;
          },
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _verifyOtp(authService),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Verify Code'),
          ),
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: (_isLoading || _onCooldown)
              ? null
              : () => _sendOtp(authService),
          child: Text(
            _onCooldown ? 'Resend in ${_cooldownSeconds}s' : 'Resend code',
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(AuthService authService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 80, color: Color(0xFF800000)),

        const SizedBox(height: 16),

        const Text(
          'Set a new password',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 24),

        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          enabled: !_isLoading,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _obscureNew = !_obscureNew;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }

            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }

            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          enabled: !_isLoading,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _updatePassword(authService),
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirm = !_obscureConfirm;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }

            if (value != _newPasswordController.text) {
              return 'Passwords do not match';
            }

            return null;
          },
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _updatePassword(authService),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Update Password'),
          ),
        ),
      ],
    );
  }
}
