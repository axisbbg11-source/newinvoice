import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

final paymentInvoiceProvider = FutureProvider.family<InvoiceModel, String>((ref, id) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase.from('invoices').select('*, clients(*)').eq('id', id).single();
  return InvoiceModel.fromJson(data);
});

class PaymentScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  const PaymentScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> with SingleTickerProviderStateMixin {
  String _selectedMethod = 'upi';
  bool _processing = false;
  bool _success = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_processing) return;
    setState(() => _processing = true);

    // Simulate payment processing delay
    await Future.delayed(const Duration(seconds: 2));

    // Mark invoice as paid in Supabase
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('invoices').update({'status': 'paid'}).eq('id', widget.invoiceId);

      setState(() {
        _processing = false;
        _success = true;
      });
      _animController.forward();

      // Wait a moment then go back
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/invoices/${widget.invoiceId}');
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(paymentInvoiceProvider(widget.invoiceId));
    final fmt = NumberFormat('#,##,###', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: invoiceAsync.when(
        data: (invoice) {
          if (_success) {
            return Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(50)),
                    child: const Icon(Icons.check_circle, size: 60, color: AppColors.success),
                  ),
                  const SizedBox(height: 24),
                  const Text('Payment Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('₹${fmt.format(invoice.total)} paid', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 32),
                  const Text('Redirecting...', style: TextStyle(color: AppColors.textMuted)),
                ]),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Invoice Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Invoice', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  ]),
                  const Divider(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Amount Due', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    Text('₹${fmt.format(invoice.total)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),

              // Payment Method
              const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
                child: Column(children: [
                  _MethodTile(
                    icon: Icons.qr_code,
                    title: 'UPI',
                    subtitle: 'Pay via UPI app',
                    selected: _selectedMethod == 'upi',
                    onTap: () => setState(() => _selectedMethod = 'upi'),
                  ),
                  const Divider(height: 1),
                  _MethodTile(
                    icon: Icons.credit_card,
                    title: 'Card',
                    subtitle: 'Debit/Credit card',
                    selected: _selectedMethod == 'card',
                    onTap: () => setState(() => _selectedMethod = 'card'),
                  ),
                  const Divider(height: 1),
                  _MethodTile(
                    icon: Icons.account_balance,
                    title: 'Bank Transfer',
                    subtitle: 'NEFT/RTGS/IMPS',
                    selected: _selectedMethod == 'bank',
                    onTap: () => setState(() => _selectedMethod = 'bank'),
                  ),
                  const Divider(height: 1),
                  _MethodTile(
                    icon: Icons.wallet,
                    title: 'Cash',
                    subtitle: 'Pay in person',
                    selected: _selectedMethod == 'cash',
                    onTap: () => setState(() => _selectedMethod = 'cash'),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // Mock Payment Form
              if (_selectedMethod == 'card' || _selectedMethod == 'bank') ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
                  child: Column(children: [
                    if (_selectedMethod == 'card') ...[
                      TextFormField(decoration: const InputDecoration(labelText: 'Card Number', hintText: '1234 5678 9012 3456')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Expiry', hintText: 'MM/YY'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'CVV', hintText: '123'))),
                      ]),
                    ] else ...[
                      const Text('Bank details will be shown after confirmation', style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Pay Button
              ElevatedButton(
                onPressed: _processing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _processing
                    ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Processing...'),
                      ])
                    : Text('Pay ₹${fmt.format(invoice.total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),

              // Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha:0.3), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(child: Text('This is a mock payment for demo purposes. No real money is processed.', style: TextStyle(fontSize: 12, color: AppColors.primary))),
                ]),
              ),
              const SizedBox(height: 80),
            ]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: selected ? AppColors.primaryLight : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ])),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
          else
            const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted, size: 22),
        ]),
      ),
    );
  }
}