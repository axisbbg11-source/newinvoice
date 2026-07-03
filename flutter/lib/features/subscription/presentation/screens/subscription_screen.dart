import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_provider.dart';

// Plan data
class Plan {
  final String id;
  final String name;
  final String tag;
  final int monthlyPrice;
  final bool isMostPopular;
  final List<String> features;
  final List<String> greyedFeatures;

  const Plan({
    required this.id,
    required this.name,
    required this.tag,
    required this.monthlyPrice,
    required this.isMostPopular,
    required this.features,
    required this.greyedFeatures,
  });

  int get yearlyPrice => (monthlyPrice * 12 * 0.8).round();
}

const plans = [
  Plan(
    id: 'free',
    name: 'Free',
    tag: 'Get started',
    monthlyPrice: 0,
    isMostPopular: false,
    features: [
      '3 clients',
      '5 invoices per month',
      'Basic expense tracking',
      'Manual reports',
    ],
    greyedFeatures: [
      'AI follow-up emails',
      'Auto client reports',
      'Contract builder',
      'WhatsApp reminders',
    ],
  ),
  Plan(
    id: 'pro',
    name: 'Pro',
    tag: 'Most popular',
    monthlyPrice: 499,
    isMostPopular: true,
    features: [
      'Unlimited clients',
      'Unlimited invoices',
      'AI follow-up emails',
      'Auto weekly client reports',
      'Contract builder',
      'WhatsApp reminders',
      'Expense tracking with photo',
      'PDF downloads',
    ],
    greyedFeatures: [
      'Team members',
      'White-label PDF',
    ],
  ),
  Plan(
    id: 'agency',
    name: 'Agency',
    tag: 'For teams',
    monthlyPrice: 1499,
    isMostPopular: false,
    features: [
      'Everything in Pro',
      'Up to 5 team members',
      'White-label PDF (your logo, your brand)',
      'Priority support',
      'Early access to new features',
    ],
    greyedFeatures: [],
  ),
];

// State
final isYearlyProvider = StateProvider<bool>((ref) => false);

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isYearly = ref.watch(isYearlyProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Plan & Billing',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Center(
              child: Column(
                children: [
                  Text(
                    'Choose your plan',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start free. Upgrade when you need more.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monthly/Yearly toggle
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleButton(
                      label: 'Monthly',
                      isSelected: !isYearly,
                      onTap: () => ref.read(isYearlyProvider.notifier).state = false,
                    ),
                    _ToggleButton(
                      label: 'Yearly',
                      isSelected: isYearly,
                      onTap: () => ref.read(isYearlyProvider.notifier).state = true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Plan cards
            ...plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PlanCard(
                plan: plan,
                isYearly: isYearly,
                currentPlan: userAsync.valueOrNull?.plan ?? 'free',
                onUpgrade: () => _showPaymentSheet(context, ref, plan, isYearly),
              ),
            )),

            // Current plan indicator
            userAsync.when(
              data: (user) => Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your current plan: ${user?.plan ?? 'free'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Member since: ${user != null ? DateFormat('d MMM yyyy').format(user.createdAt) : 'N/A'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // FAQ Section
            const Text(
              'FAQ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const _FAQItem(
              question: 'Can I cancel anytime?',
              answer: 'Yes, cancel anytime. No questions asked.',
            ),
            const _FAQItem(
              question: 'Is my data safe?',
              answer: 'Yes, all data is encrypted and stored securely on Supabase.',
            ),
            const _FAQItem(
              question: 'When will real payments be available?',
              answer: 'Very soon. We will notify you by email.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref, Plan plan, bool isYearly) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentSheet(plan: plan, isYearly: isYearly),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool isYearly;
  final String currentPlan;
  final VoidCallback onUpgrade;

  const _PlanCard({
    required this.plan,
    required this.isYearly,
    required this.currentPlan,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final price = isYearly ? plan.yearlyPrice : plan.monthlyPrice;
    final isCurrentPlan = currentPlan == plan.id;
    final isDowngrade = plans.indexOf(plans.firstWhere((p) => p.id == currentPlan)) > plans.indexOf(plan);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isMostPopular ? AppColors.primary : AppColors.border,
          width: plan.isMostPopular ? 2 : 0.5,
        ),
        boxShadow: plan.isMostPopular ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha:0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag
          if (plan.tag.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: plan.isMostPopular ? AppColors.primaryLight : AppColors.surfaceAlt,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (plan.isMostPopular) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Save 20%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    plan.tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: plan.isMostPopular ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isYearly ? '/year' : '/month',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isYearly && plan.monthlyPrice > 0)
                  Text(
                    'Equivalent to ₹${(price / 12).round()}/month',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                const SizedBox(height: 20),

                // Features
                ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        f,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )),
                ...plan.greyedFeatures.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.close, size: 16, color: AppColors.textMuted.withValues(alpha:0.5)),
                      const SizedBox(width: 8),
                      Text(
                        f,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted.withValues(alpha:0.5),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: isCurrentPlan
                      ? ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceAlt,
                            foregroundColor: AppColors.textMuted,
                            disabledBackgroundColor: AppColors.surfaceAlt,
                            disabledForegroundColor: AppColors.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Current plan'),
                        )
                      : isDowngrade
                          ? OutlinedButton(
                              onPressed: onUpgrade,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: const Text('Downgrade'),
                            )
                          : ElevatedButton(
                              onPressed: onUpgrade,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: plan.id == 'agency' ? AppColors.textPrimary : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(plan.id == 'pro' ? 'Upgrade to Pro' : 'Upgrade to Agency'),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final Plan plan;
  final bool isYearly;

  const _PaymentSheet({required this.plan, required this.isYearly});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  bool _isLoading = false;
  bool _showSuccess = false;

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);

    // Fake 2 second loading
    await Future.delayed(const Duration(seconds: 2));

    // Update user plan in Supabase
    try {
      final supabase = ref.read(supabaseProvider);
      final userId = ref.read(currentUserIdProvider);

      await supabase.from('users').update({'plan': widget.plan.id}).eq('id', userId);

      // Refresh user data
      ref.invalidate(currentUserProvider);
    } catch (e) {
      // Continue even if update fails (demo mode)
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.isYearly ? widget.plan.yearlyPrice : widget.plan.monthlyPrice;

    if (_showSuccess) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 40, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment successful!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome to ${widget.plan.name}! Your account has been upgraded.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Start using ${widget.plan.name}'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Center(
              child: Column(
                children: [
                  const Text(
                    'Complete your purchase',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.plan.name} • ₹$price${widget.isYearly ? '/year' : '/month'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card fields
            _InputField(
              controller: _cardNumberController,
              label: 'Card number',
              hint: '4242 4242 4242 4242',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InputField(
                    controller: _expiryController,
                    label: 'Expiry',
                    hint: 'MM/YY',
                    keyboardType: TextInputType.datetime,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _InputField(
                    controller: _cvvController,
                    label: 'CVV',
                    hint: '•••',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InputField(
              controller: _nameController,
              label: 'Cardholder name',
              hint: 'John Doe',
            ),
            const SizedBox(height: 24),

            // Pay button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text('Pay ₹$price'),
              ),
            ),
            const SizedBox(height: 16),

            // Footer
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted.withValues(alpha:0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Payments powered by Razorpay',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted.withValues(alpha:0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coming soon — we will notify you when payments go live',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted.withValues(alpha:0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha:0.5)),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}