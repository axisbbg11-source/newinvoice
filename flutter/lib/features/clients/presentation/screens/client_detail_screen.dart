import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

final clientDetailProvider = FutureProvider.family<ClientModel, String>((ref, id) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase.from('clients').select().eq('id', id).single();
  return ClientModel.fromJson(data);
});

final clientInvoicesProvider = FutureProvider.family<List<InvoiceModel>, String>((ref, clientId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase.from('invoices').select('*, clients(*)').eq('client_id', clientId).order('created_at', ascending: false);
  return (data as List).map((j) => InvoiceModel.fromJson(j)).toList();
});

// Provider for client invoice summary
final clientInvoiceSummaryProvider = FutureProvider.family<Map<String, double>, String>((ref, clientId) async {
  final invoices = await ref.watch(clientInvoicesProvider(clientId).future);
  double totalPaid = 0, totalOwed = 0;
  for (final inv in invoices) {
    if (inv.status == 'paid') {
      totalPaid += inv.total;
    } else {
      totalOwed += inv.total;
    }
  }
  return {'paid': totalPaid, 'owed': totalOwed};
});

class ClientDetailScreen extends ConsumerWidget {
  final String id;
  const ClientDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientDetailProvider(id));
    final invoices = ref.watch(clientInvoicesProvider(id));
    final summary = ref.watch(clientInvoiceSummaryProvider(id));
    final fmt = NumberFormat('#,##,###', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                // Navigate to edit - we'll reuse add client screen with edit mode
                context.push('/clients/add?edit=$id');
              } else if (v == 'delete') {
                // Confirm before delete
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Client'),
                    content: const Text('Are you sure? This will also delete all their invoices.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final supabase = ref.read(supabaseProvider);
                  await supabase.from('clients').delete().eq('id', id);
                  if (context.mounted) context.pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Edit')]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete, size: 20, color: AppColors.danger), SizedBox(width: 12), Text('Delete', style: TextStyle(color: AppColors.danger))]),
              ),
            ],
          ),
        ],
      ),
      body: client.when(
        data: (c) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clientDetailProvider(id));
            ref.invalidate(clientInvoicesProvider(id));
            ref.invalidate(clientInvoiceSummaryProvider(id));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppColors.cardDecoration,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          c.initials,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            if (c.email != null)
                              Text(
                                c.email!,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            if (c.phone != null)
                              Text(
                                c.phone!,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary cards
                summary.when(
                  data: (s) => Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Paid',
                                style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${fmt.format(s['paid'])}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: s['owed']! > 0 ? AppColors.warningLight : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: s['owed']! > 0 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Owed',
                                style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${fmt.format(s['owed'])}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: s['owed']! > 0 ? AppColors.warning : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Quick action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/invoices/create'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Invoice'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (c.phone != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('https://wa.me/${c.phone}');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                  ],
                ),
                if (c.email != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('mailto:${c.email}?subject=Hello ${c.name}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Send Email'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                ],
                const SizedBox(height: 24),

                // Details card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppColors.cardDecoration,
                  child: Column(
                    children: [
                      if (c.address != null) _DetailRow(label: 'Address', value: c.address!),
                      if (c.address != null) const Divider(height: 24),
                      _DetailRow(label: 'WhatsApp Reminders', value: c.whatsappEnabled ? 'Enabled' : 'Disabled'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Invoices header
                const Text(
                  'Invoices',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                invoices.when(
                  data: (list) => list.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AppColors.cardDecoration,
                          child: const Center(
                            child: Text('No invoices for this client', style: TextStyle(color: AppColors.textMuted)),
                          ),
                        )
                      : Column(
                          children: list.map(
                            (inv) {
                              Color statusColor;
                              String statusLabel;
                              switch (inv.status) {
                                case 'paid':
                                  statusColor = AppColors.success;
                                  statusLabel = 'Paid';
                                  break;
                                case 'overdue':
                                  statusColor = AppColors.danger;
                                  statusLabel = 'Overdue';
                                  break;
                                default:
                                  statusColor = AppColors.warning;
                                  statusLabel = 'Pending';
                              }
                              return GestureDetector(
                                onTap: () => context.push('/invoices/${inv.id}'),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: AppColors.cardDecoration,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inv.invoiceNumber,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                            ),
                                            Text(
                                              DateFormat('d MMM yyyy').format(inv.dueDate),
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${fmt.format(inv.total)}',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: statusColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}