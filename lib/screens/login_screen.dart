import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_service.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Separate keys per form to avoid GlobalKey conflicts between
  // the login/register form and the OTP form.
  final _authFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  static const int _cooldownDuration = 60; // matches Supabase's server cooldown

  bool _isLogin = true;
  bool _otpSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  bool _canSubmit = true;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.user != null) {
      return const MainScreen();
    }

    return _otpSent ? _buildOtpForm(authService) : _buildAuthForm();
  }

  Widget _buildAuthForm() {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _authFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/University_of_Mindanao_Logo.png',
                  height: 100,
                ),
                const SizedBox(height: 20),
                Text(
                  _isLogin ? 'Welcome Back!' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Sign in with your UM email'
                      : 'Register using your UM email',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g., Juan Dela Cruz',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'UM Email',
                    hintText: 'yourname@umindanao.edu.ph',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Please enter your email';
                    if (!email.endsWith('@umindanao.edu.ph')) {
                      return 'Only UM email addresses are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
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

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    // Only gated by _isLoading now — the OTP resend
                    // cooldown must never block the login/register
                    // button, since it's a completely separate action.
                    onPressed: _isLoading
                        ? null
                        : () => _submit(context.read<AuthService>()),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isLogin ? 'Sign In' : 'Register'),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? "Don't have an account?"
                          : 'Already have an account?',
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _passwordController.clear();
                                _confirmPasswordController.clear();
                              });
                            },
                      child: Text(_isLogin ? 'Register' : 'Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpForm(AuthService authService) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _otpFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: Color(0xFF800000),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter the verification code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a code to ${_emailController.text.trim()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 8, // Supabase's OTP length is a project
                  // setting (GOTRUE_MAILER_OTP_LENGTH) and isn't
                  // guaranteed to be 6 — some projects default to 8.
                  // We allow up to 8 and validate loosely below so a
                  // valid code is never rejected client-side.
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    prefixIcon: Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(),
                    counterText:
                        '', // hide the x/8 counter, it's not meaningful here
                  ),
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (code.isEmpty) {
                      return 'Enter the code from your email';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(code)) {
                      return 'Code must contain only numbers';
                    }
                    if (code.length < 6 || code.length > 8) {
                      return 'Enter the full code from your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _verifyOtp(authService),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify & Continue'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_canSubmit && !_isLoading)
                      ? () => _resendOtp(authService)
                      : null,
                  child: Text(
                    _canSubmit
                        ? 'Resend code'
                        : 'Resend in $_cooldownSeconds s',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                            // Reset cooldown state — it's scoped to the
                            // OTP screen only and shouldn't linger.
                            _canSubmit = true;
                            _cooldownSeconds = 0;
                          });
                        },
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Single reusable cooldown starter — used after both the initial OTP
  /// send and every resend, so the UI always reflects Supabase's real
  /// server-side rate limit instead of drifting out of sync with it.
  Future<void> _startCooldown() async {
    setState(() {
      _canSubmit = false;
      _cooldownSeconds = _cooldownDuration;
    });
    while (_cooldownSeconds > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _cooldownSeconds--);
    }
    if (mounted) setState(() => _canSubmit = true);
  }

  Future<void> _submit(AuthService authService) async {
    if (!_authFormKey.currentState!.validate()) return;
    if (_isLoading)
      return; // guard against double-tap while a request is in flight

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        // On success, auth listener navigates automatically.
      } else {
        // signUp() only creates the account (or confirms one is
        // already pending) — it does NOT send the OTP. That keeps a
        // slow/failed email from ever blocking navigation.
        await authService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          name: _nameController.text.trim(),
        );

        // Move to the PIN screen unconditionally once account
        // creation itself succeeded (or the account already existed
        // unconfirmed) — never let the OTP step gate this transition.
        if (!mounted) return;
        setState(() => _otpSent = true);

        // Send the OTP as its own step with its own error handling.
        // A failure here just shows a message and leaves the user on
        // the PIN screen with a working "Resend" button — it never
        // throws them back to the registration form.
        await _sendInitialOtp(authService);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sends the first OTP after landing on the PIN screen. Failures are
  /// shown inline but do not navigate away — the user can always tap
  /// "Resend code" to try again once the cooldown clears.
  Future<void> _sendInitialOtp(AuthService authService) async {
    try {
      await authService.sendEmailOtp(_emailController.text.trim());
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send the code ($e). Tap Resend to try again.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      // No cooldown started since no code actually went out — the
      // Resend button stays immediately usable.
    }
  }

  Future<void> _resendOtp(AuthService authService) async {
    setState(() => _isLoading = true);
    try {
      await authService.resendEmailOtp(_emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('New code sent!')));
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp(AuthService authService) async {
    if (!_otpFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await authService.verifyEmailOtp(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
      );
      // On success, auth state listener navigates to MainScreen.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
