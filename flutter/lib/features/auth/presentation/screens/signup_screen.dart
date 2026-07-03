import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

// Signup Screen
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _bizCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true, _loading = false;
  bool _emailSent = false;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await ref.read(authProvider.notifier).signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          name: _nameCtrl.text.trim(),
          businessName: _bizCtrl.text.trim(),
        );

    if (!mounted) return;

    final state = ref.read(authProvider);

    state.when(
      data: (user) {
        if (user != null) {
          // Success - go to onboarding
          context.go('/onboarding');
        } else {
          // Email confirmation required - show message
          setState(() {
            _loading = false;
            _emailSent = true;
          });
        }
      },
      error: (e, _) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      },
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/login'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _emailSent
              ? _buildEmailSent()
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Start managing your business for free',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      // Name field
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 14),
                      // Business name field
                      TextFormField(
                        controller: _bizCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Business name',
                          prefixIcon: Icon(Icons.store_outlined, size: 18),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter business name' : null,
                      ),
                      const SizedBox(height: 14),
                      // Email field
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline, size: 18),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter email' : null,
                      ),
                      const SizedBox(height: 14),
                      // Password field
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                      ),
                      const SizedBox(height: 28),
                      // Sign up button (full-width, consistent height)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signup,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text(
                              'Sign in',
                              style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
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

  Widget _buildEmailSent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: AppColors.success, size: 40),
        ),
        const SizedBox(height: 24),
        const Text(
          'Check your email',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a confirmation link to\n${_emailCtrl.text}',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const Text(
          'Click the link to verify your account, then come back to login.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text('Change email'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Go to login'),
        ),
      ],
    );
  }
}

// Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _pages = [
    const _OnboardPage(
      icon: Icons.receipt_long,
      title: 'Create invoices in 60 seconds',
      subtitle: 'Add client, items, amount — done. Share via WhatsApp or email instantly.',
      color: AppColors.primary,
    ),
    const _OnboardPage(
      icon: Icons.auto_awesome,
      title: 'AI chases payments for you',
      subtitle: 'Overdue invoice? AI automatically sends follow-up emails so you never have to ask awkwardly.',
      color: AppColors.accent,
    ),
    const _OnboardPage(
      icon: Icons.insights,
      title: 'Know your numbers always',
      subtitle: 'Money in, money out, who owes you — all on one screen. No accountant needed.',
      color: AppColors.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_page < _pages.length - 1) {
                          _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        } else {
                          context.go('/home');
                        }
                      },
                      child: Text(_page < _pages.length - 1 ? 'Next' : "Let's go"),
                    ),
                  ),
                  if (_page < _pages.length - 1) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Skip', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;

  const _OnboardPage({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: color, size: 44),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}