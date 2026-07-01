import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

// Filter state
final invoiceFilterProvider = StateProvider<String>((ref) => 'all');

final invoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('invoices').select('*, clients(*)').eq('user_id', uid).order('created_at', ascending: false);
  return (data as List).map((j) => InvoiceModel.fromJson(j)).toList();
});

final filteredInvoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  final invoices = await ref.watch(invoicesProvider.future);
  final filter = ref.watch(invoiceFilterProvider);
  if (filter == 'all') return invoices;
  return invoices.where((inv) => inv.status == filter).toList();
});

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(filteredInvoicesProvider);
    final currentFilter = ref.watch(invoiceFilterProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
              child: Text('Invoices', style: AppTextStyles.pageTitle),
            ),

            // Filter tabs - segmented control style
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All',
                      value: 'all',
                      current: currentFilter,
                      count: invoices.valueOrNull?.length ?? 0,
                      onTap: () => ref.read(invoiceFilterProvider.notifier).state = 'all',
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Pending',
                      value: 'pending',
                      current: currentFilter,
                      count: invoices.valueOrNull?.where((i) => i.status == 'pending').length ?? 0,
                      onTap: () => ref.read(invoiceFilterProvider.notifier).state = 'pending',
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Overdue',
                      value: 'overdue',
                      current: currentFilter,
                      count: invoices.valueOrNull?.where((i) => i.status == 'overdue').length ?? 0,
                      onTap: () => ref.read(invoiceFilterProvider.notifier).state = 'overdue',
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Paid',
                      value: 'paid',
                      current: currentFilter,
                      count: invoices.valueOrNull?.where((i) => i.status == 'paid').length ?? 0,
                      onTap: () => ref.read(invoiceFilterProvider.notifier).state = 'paid',
                    ),
                  ],
                ),
              ),
            ),

            // Invoice list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(invoicesProvider);
                  ref.invalidate(filteredInvoicesProvider);
                },
                child: invoices.when(
                  data: (list) => list.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.brandTint,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.brand),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No ${currentFilter == 'all' ? '' : currentFilter} invoices',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currentFilter == 'all' ? 'Create your first invoice to get started' : 'No invoices with this status',
                                  style: AppTextStyles.body,
                                  textAlign: TextAlign.center,
                                ),
                                if (currentFilter == 'all') ...[
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => context.push('/invoices/create'),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Create Invoice'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final inv = list[i];
                            return _InvoiceCard(invoice: inv, fmt: fmt);
                          },
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.rose))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Filter pill widget
class _FilterPill extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;
  final int count;

  const _FilterPill({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Invoice card widget
class _InvoiceCard extends ConsumerWidget {
  final InvoiceModel invoice;
  final NumberFormat fmt;

  const _InvoiceCard({required this.invoice, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color statusColor;
    Color statusBgColor;
    String statusLabel;
    switch (invoice.status) {
      case 'paid':
        statusColor = AppColors.emerald;
        statusBgColor = AppColors.emeraldTint;
        statusLabel = 'Paid';
        break;
      case 'overdue':
        statusColor = AppColors.rose;
        statusBgColor = AppColors.roseTint;
        statusLabel = 'Overdue';
        break;
      default:
        statusColor = AppColors.amber;
        statusBgColor = AppColors.amberTint;
        statusLabel = 'Pending';
    }

    return Dismissible(
      key: Key(invoice.id),
      direction: invoice.status != 'paid' ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.emerald,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      ),
      confirmDismiss: (dir) async {
        if (invoice.status == 'paid') return false;
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mark as Paid?'),
            content: Text('Mark invoice ${invoice.invoiceNumber} as paid?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final supabase = ref.read(supabaseProvider);
        await supabase.from('invoices').update({'status': 'paid'}).eq('id', invoice.id);
        ref.invalidate(invoicesProvider);
        ref.invalidate(filteredInvoicesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invoice ${invoice.invoiceNumber} marked as paid'),
            backgroundColor: AppColors.emerald,
          ));
        }
      },
      child: GestureDetector(
        onTap: () => context.push('/invoices/${invoice.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Invoice ID + Status chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(invoice.invoiceNumber, style: AppTextStyles.invoiceId),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTextStyles.chip.copyWith(color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Bottom row: Client info + Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Client info
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            invoice.client?.initials ?? '?',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandDark,
                              letterSpacing: 0.02,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.client?.name ?? 'Unknown',
                            style: AppTextStyles.cardTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            invoice.isOverdue
                                ? 'Due ${invoice.daysOverdue} days ago'
                                : 'Due ${DateFormat('d MMM yyyy').format(invoice.dueDate)}',
                            style: AppTextStyles.body.copyWith(
                              color: invoice.isOverdue ? AppColors.rose : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Amount
                  Text(
                    '₹${fmt.format(invoice.total)}',
                    style: AppTextStyles.amount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}