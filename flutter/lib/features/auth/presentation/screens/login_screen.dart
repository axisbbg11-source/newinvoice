import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendOtpLoading = false;
  bool _verifyOtpLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verify OTP before signing in.')),
      );
      return;
    }
    setState(() => _loading = true);

    await ref.read(authProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );

    if (!mounted) return;

    setState(() => _loading = false);

    final state = ref.read(authProvider);
    state.when(
      data: (user) {
        if (user != null) {
          context.go('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Please try again.')),
          );
        }
      },
      error: (e, _) {
        String message = e.toString();
        if (message.contains('Invalid login') || message.contains('invalid credentials')) {
          message = 'Invalid email or password';
        } else if (message.contains('User not found')) {
          message = 'No account found with this email';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
      loading: () {},
    );
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (email.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and phone first.')),
      );
      return;
    }

    setState(() {
      _sendOtpLoading = true;
      _otpSent = false;
      _otpVerified = false;
    });

    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/auth/send-otp');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'phone': phone}),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _otpSent = true;
          _otpVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent. Check your phone.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP send failed: ${res.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP send error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendOtpLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final code = _otpCtrl.text.trim();
    if (email.isEmpty || phone.isEmpty || code.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email, phone, and OTP code.')),
      );
      return;
    }

    setState(() => _verifyOtpLoading = true);

    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/auth/verify-otp');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'phone': phone, 'code': code}),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _otpVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verified successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verify failed: ${res.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP verify error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _verifyOtpLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 16),

                // App name
                const Center(
                  child: Text(
                    'BizDesk',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 20),

                // Wordmark
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    children: [
                      TextSpan(text: 'biz', style: TextStyle(color: AppColors.primary)),
                      TextSpan(text: 'desk', style: TextStyle(color: AppColors.accent)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to manage your business',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),

                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'name@company.com',
                    prefixIcon: Icon(Icons.mail_outline, size: 18),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter your email' : null,
                  onChanged: (_) {
                    if (_otpVerified) {
                      setState(() => _otpVerified = false);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Phone field (for OTP)
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: '+1234567890',
                    prefixIcon: Icon(Icons.phone, size: 18),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter your phone number' : null,
                  onChanged: (_) {
                    if (_otpVerified) {
                      setState(() => _otpVerified = false);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendOtpLoading ? null : _sendOtp,
                        child: _sendOtpLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Send OTP'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _verifyOtpLoading ? null : _verifyOtp,
                        child: _verifyOtpLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Verify OTP'),
                      ),
                    ),
                  ],
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: Icon(Icons.lock_clock, size: 18),
                    ),
                    validator: (v) => _otpSent && v!.isEmpty ? 'Enter the OTP code' : null,
                    onChanged: (_) {
                      if (_otpVerified) {
                        setState(() => _otpVerified = false);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (_otpSent)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _otpVerified ? 'OTP verified ✔' : 'OTP sent — verify it before signing in',
                      style: TextStyle(
                        color: _otpVerified ? Colors.green : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                // Password field
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter your password' : null,
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot password?', style: TextStyle(fontSize: 13, color: AppColors.accent)),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign in button (full-width, consistent height)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: AppColors.border)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or continue with', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    Expanded(child: Container(height: 1, color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 16),

                // Social row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.g_mobiledata, size: 22, color: AppColors.textPrimary),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.accent),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/signup'),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
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

}