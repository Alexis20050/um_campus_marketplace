import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_service.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  static const int _cooldownDuration = 60;

  bool _isLogin = true;
  bool _otpSent = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;

  bool _canSubmit = true;
  int _cooldownSeconds = 0;

  AuthService? _authService;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _authService = context.read<AuthService>();
      _authService!.addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChanged);

    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();

    super.dispose();
  }

  void _onAuthChanged() {
    final message = _authService?.authMessage;

    if (message == null || !mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );

    _authService?.clearAuthMessage();
  }

  // ============================================================
  // INPUT DESIGN
  // ============================================================

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final brand = AppColors.brandOf(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,

      prefixIcon: Icon(icon, color: brand, size: 21),

      suffixIcon: suffix,

      filled: true,
      fillColor: AppColors.surfaceAltOf(context),

      labelStyle: TextStyle(
        color: AppColors.textSecondaryOf(context),
        fontSize: 14,
      ),

      floatingLabelStyle: TextStyle(color: brand, fontWeight: FontWeight.w600),

      hintStyle: TextStyle(
        color: AppColors.textTertiaryOf(context),
        fontSize: 14,
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.borderOf(context)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: brand, width: 1.8),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
      ),

      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
    );
  }

  TextStyle get _fieldTextStyle {
    return TextStyle(
      color: AppColors.textPrimaryOf(context),
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    // Keep your current navigation behavior for now.
    if (authService.user != null) {
      return const MainScreen();
    }

    return _otpSent ? _buildOtpScreen(authService) : _buildAuthScreen();
  }

  // ============================================================
  // LOGIN / REGISTER
  // ============================================================

  Widget _buildAuthScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final brand = AppColors.brandOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _authFormKey,
                  child: Column(
                    children: [
                      // =================================================
                      // LOGO
                      // =================================================
                      Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.borderOf(context),
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: AppColors.shadowOf(context),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/University_of_Mindanao_Logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // =================================================
                      // TITLE
                      // =================================================
                      Text(
                        'UM Campus Marketplace',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _isLogin
                            ? 'Sign in to your marketplace account'
                            : 'Create your marketplace account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 26),

                      // =================================================
                      // MAIN CARD
                      // =================================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.borderOf(context),
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: AppColors.shadowOf(context),
                                blurRadius: 20,
                                offset: const Offset(0, 7),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ===========================================
                            // NAME - REGISTER ONLY
                            // ===========================================
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _nameController,
                                style: _fieldTextStyle,
                                cursorColor: brand,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: _fieldDecoration(
                                  label: 'Full Name',
                                  hint: 'Juan Dela Cruz',
                                  icon: Icons.person_outline,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),
                            ],

                            // ===========================================
                            // EMAIL
                            // ===========================================
                            TextFormField(
                              controller: _emailController,
                              style: _fieldTextStyle,
                              cursorColor: brand,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.email],
                              decoration: _fieldDecoration(
                                label: _isLogin ? 'Email' : 'UM Email',
                                hint: _isLogin
                                    ? 'Enter your email'
                                    : 'yourname@umindanao.edu.ph',
                                icon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                final email = value?.trim().toLowerCase() ?? '';

                                if (email.isEmpty) {
                                  return 'Please enter your email';
                                }

                                if (!email.contains('@')) {
                                  return 'Enter a valid email address';
                                }

                                final auth = context.read<AuthService>();

                                // Registration remains UM-only.
                                if (!_isLogin && !auth.isUMEmail(email)) {
                                  return 'Only UM email addresses can register';
                                }

                                // Login allows UM + authorized admin.
                                if (_isLogin &&
                                    !auth.isAllowedLoginEmail(email)) {
                                  return 'This account is not authorized';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ===========================================
                            // PASSWORD
                            // ===========================================
                            TextFormField(
                              controller: _passwordController,
                              style: _fieldTextStyle,
                              cursorColor: brand,
                              obscureText: _obscurePassword,
                              autofillHints: _isLogin
                                  ? const [AutofillHints.password]
                                  : const [AutofillHints.newPassword],
                              textInputAction: _isLogin
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              onFieldSubmitted: (_) {
                                if (_isLogin && !_isLoading) {
                                  _submit(context.read<AuthService>());
                                }
                              },
                              decoration: _fieldDecoration(
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline,
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }

                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }

                                return null;
                              },
                            ),

                            // ===========================================
                            // FORGOT PASSWORD
                            // ===========================================
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ForgotPasswordScreen(),
                                            ),
                                          );
                                        },
                                  style: TextButton.styleFrom(
                                    foregroundColor: brand,
                                    padding: const EdgeInsets.only(
                                      top: 9,
                                      bottom: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 16),

                            // ===========================================
                            // CONFIRM PASSWORD
                            // ===========================================
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _confirmPasswordController,
                                style: _fieldTextStyle,
                                cursorColor: brand,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) {
                                    _submit(context.read<AuthService>());
                                  }
                                },
                                decoration: _fieldDecoration(
                                  label: 'Confirm Password',
                                  hint: 'Enter your password again',
                                  icon: Icons.lock_outline,
                                  suffix: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondaryOf(context),
                                    ),
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

                              const SizedBox(height: 20),
                            ],

                            // ===========================================
                            // PRIMARY BUTTON
                            // ===========================================
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () =>
                                          _submit(context.read<AuthService>()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.maroon,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.maroon
                                      .withValues(alpha: 0.45),
                                  disabledForegroundColor: Colors.white70,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? 'Sign In' : 'Create Account',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ===========================================
                            // OR
                            // ===========================================
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.borderOf(context),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: AppColors.textTertiaryOf(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.borderOf(context),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // ===========================================
                            // GOOGLE
                            // ===========================================
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () => _submitGoogle(
                                        context.read<AuthService>(),
                                      ),
                                icon: Image.network(
                                  'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                                  width: 21,
                                  height: 21,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.login,
                                    size: 20,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceAltOf(
                                    context,
                                  ),
                                  foregroundColor: AppColors.textPrimaryOf(
                                    context,
                                  ),
                                  side: BorderSide(
                                    color: AppColors.borderOf(context),
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================================================
                      // SWITCH LOGIN / REGISTER
                      // =================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? "Don't have an account?"
                                : 'Already have an account?',
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(width: 3),

                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();

                                    setState(() {
                                      _isLogin = !_isLogin;

                                      _passwordController.clear();

                                      _confirmPasswordController.clear();

                                      _obscurePassword = true;

                                      _obscureConfirmPassword = true;
                                    });

                                    _authFormKey.currentState?.reset();
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: brand,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                            ),
                            child: Text(
                              _isLogin ? 'Create Account' : 'Sign In',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (!_isLogin)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Registration requires a University of Mindanao email.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textTertiaryOf(context),
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OTP
  // ============================================================

  Widget _buildOtpScreen(AuthService authService) {
    final primary = AppColors.textPrimaryOf(context);

    final secondary = AppColors.textSecondaryOf(context);

    final brand = AppColors.brandOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _otpFormKey,
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: AppColors.brandSoftOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 45,
                        color: brand,
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'Verify your email',
                      style: TextStyle(
                        color: primary,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enter the verification code sent to',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary, fontSize: 13),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _emailController.text.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: brand,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 26),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            cursorColor: brand,
                            style: TextStyle(
                              color: primary,
                              fontSize: 24,
                              letterSpacing: 7,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _fieldDecoration(
                              label: 'Verification Code',
                              hint: '123456',
                              icon: Icons.pin_outlined,
                            ).copyWith(counterText: ''),
                            validator: (value) {
                              final code = value?.trim() ?? '';

                              if (code.isEmpty) {
                                return 'Enter the verification code';
                              }

                              if (!RegExp(r'^\d+$').hasMatch(code)) {
                                return 'Code must contain numbers only';
                              }

                              if (code.length < 6 || code.length > 8) {
                                return 'Enter the complete code';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _verifyOtp(authService),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.maroon,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Verify & Continue',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          TextButton(
                            onPressed: (_canSubmit && !_isLoading)
                                ? () => _resendOtp(authService)
                                : null,
                            child: Text(
                              _canSubmit
                                  ? 'Resend code'
                                  : 'Resend in $_cooldownSeconds s',
                              style: TextStyle(
                                color: _canSubmit
                                    ? brand
                                    : AppColors.textTertiaryOf(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _otpSent = false;
                                _otpController.clear();

                                _canSubmit = true;

                                _cooldownSeconds = 0;
                              });
                            },
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Sign In'),
                      style: TextButton.styleFrom(foregroundColor: secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COOLDOWN
  // ============================================================

  Future<void> _startCooldown() async {
    if (!mounted) return;

    setState(() {
      _canSubmit = false;
      _cooldownSeconds = _cooldownDuration;
    });

    while (_cooldownSeconds > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      setState(() {
        _cooldownSeconds--;
      });
    }

    if (!mounted) return;

    setState(() {
      _canSubmit = true;
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit(AuthService authService) async {
    FocusScope.of(context).unfocus();

    if (!_authFormKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();

      final password = _passwordController.text.trim();

      if (_isLogin) {
        await authService.signIn(email, password);
      } else {
        await authService.signUp(
          email,
          password,
          name: _nameController.text.trim(),
        );

        if (!mounted) return;

        setState(() {
          _otpSent = true;
        });

        await _sendInitialOtp(authService);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // GOOGLE
  // ============================================================

  Future<void> _submitGoogle(AuthService authService) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // INITIAL OTP
  // ============================================================

  Future<void> _sendInitialOtp(AuthService authService) async {
    try {
      await authService.sendEmailOtp(
        _emailController.text.trim().toLowerCase(),
      );

      _startCooldown();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send the code. $e'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> _resendOtp(AuthService authService) async {
    if (_isLoading || !_canSubmit) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.resendEmailOtp(
        _emailController.text.trim().toLowerCase(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New verification code sent!'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );

      _startCooldown();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyOtp(AuthService authService) async {
    if (!_otpFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.verifyEmailOtp(
        email: _emailController.text.trim().toLowerCase(),
        token: _otpController.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
