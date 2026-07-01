import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../data/models/models.dart';

final invoiceDetailProvider = FutureProvider.family<InvoiceModel, String>((ref, id) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase.from('invoices').select('*, clients(*)').eq('id', id).single();
  return InvoiceModel.fromJson(data);
});

// Provider for followup logs
final followupLogsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, invoiceId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase.from('followup_logs').select().eq('invoice_id', invoiceId).order('created_at', ascending: false);
  return (data as List).map((j) => Map<String, dynamic>.from(j)).toList();
});

class InvoiceDetailScreen extends ConsumerWidget {
  final String id;
  const InvoiceDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceDetailProvider(id));
    final followupLogs = ref.watch(followupLogsProvider(id));
    final userAsync = ref.watch(currentUserProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');
    final user = userAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final supabase = ref.read(supabaseProvider);
                await supabase.from('invoices').delete().eq('id', id);
                if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Delete Invoice'))],
          ),
        ],
      ),
      body: invoice.when(
        data: (inv) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(invoiceDetailProvider(id));
            ref.invalidate(followupLogsProvider(id));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppColors.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            inv.invoiceNumber,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(inv.status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _statusLabel(inv.status),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _statusColor(inv.status)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Client',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => context.push('/clients/${inv.clientId}'),
                        child: Text(
                          inv.client?.name ?? 'Unknown',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dates card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppColors.cardDecoration,
                  child: Column(
                    children: [
                      _DateRow(label: 'Invoice date', value: DateFormat('d MMM yyyy').format(inv.invoiceDate)),
                      const Divider(height: 24),
                      _DateRow(label: 'Due date', value: DateFormat('d MMM yyyy').format(inv.dueDate)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Items card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppColors.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      ...inv.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                                    Text(
                                      '${item.quantity} x ₹${fmt.format(item.price)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${fmt.format(item.total)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text(
                            '₹${fmt.format(inv.total)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Notes card
                if (inv.notes != null && inv.notes!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppColors.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(inv.notes!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Followup logs
                followupLogs.when(
                  data: (logs) {
                    if (logs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Follow-up History',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppColors.cardDecoration,
                          child: Column(
                            children: logs
                                .map<Widget>(
                                  (log) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.email_outlined, size: 16, color: AppColors.primary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                log['type']?.toString() ?? 'Follow-up',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                              ),
                                              Text(
                                                DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(log['created_at'].toString())),
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // Action buttons
                if (inv.status != 'paid') ...[
                  ElevatedButton.icon(
                    onPressed: () => context.push('/payment/$id'),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      // Show option to send thank you email
                      final sendThankYou = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Mark as Paid'),
                          content: const Text('Do you want to send a thank you email to the client?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Send Email')),
                          ],
                        ),
                      );

                      final supabase = ref.read(supabaseProvider);
                      await supabase.from('invoices').update({'status': 'paid'}).eq('id', id);
                      ref.invalidate(invoiceDetailProvider(id));

                      if (sendThankYou == true && inv.client?.email != null) {
                        try {
                          await http.post(
                            Uri.parse('${AppConstants.apiBaseUrl}/api/v1/invoices/send-thankyou'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'client_email': inv.client!.email,
                              'client_name': inv.client!.name,
                              'business_name': user?.businessName ?? 'My Business',
                              'invoice_number': inv.invoiceNumber,
                              'amount': inv.total,
                            }),
                          );
                        } catch (e) {
                          debugPrint('Failed to send thank you: $e');
                        }
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sendThankYou == true ? 'Invoice marked as paid & thank you email sent!' : 'Invoice marked as paid'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark as Paid'),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    if (inv.client?.phone != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final phone = inv.client!.phone!.replaceAll(RegExp(r'[^0-9]'), '');
                            final uri = Uri.parse('https://wa.me/$phone?text=Hi ${inv.client!.name}, please find your invoice ${inv.invoiceNumber} (₹${fmt.format(inv.total)}) attached.');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    const SizedBox(width: 10),
                    if (inv.client?.email != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // Show loading
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending email...')));
                            }
                            try {
                              // Call backend to send auto-email
                              final resp = await http.post(
                                Uri.parse('${AppConstants.apiBaseUrl}/api/v1/invoices/send-reminder'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'invoice_id': inv.id,
                                  'client_email': inv.client!.email,
                                  'client_name': inv.client!.name,
                                  'business_name': user?.businessName ?? 'My Business',
                                  'invoice_number': inv.invoiceNumber,
                                  'amount': inv.total,
                                  'due_date': DateFormat('d MMM yyyy').format(inv.dueDate),
                                  'invoice_date': DateFormat('d MMM yyyy').format(inv.invoiceDate),
                                  'status': inv.status,
                                  'notes': inv.notes,
                                }),
                              );
                              if (context.mounted) {
                                final data = jsonDecode(resp.body);
                                if (data['success'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sent automatically!'), backgroundColor: AppColors.success));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['error']}')));
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
                              }
                            }
                          },
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Send Email'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // PDF Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await PdfService.shareInvoice(
                              inv,
                              businessName: user?.businessName ?? 'My Business',
                              businessAddress: user?.address ?? 'Your Address',
                              businessPhone: user?.phone,
                              businessEmail: user?.email,
                            );
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
                          }
                        },
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await PdfService.printInvoice(inv, businessName: user?.businessName ?? 'My Business');
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing: $e')));
                          }
                        },
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Print'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Backend PDF (if already generated)
                if (inv.pdfUrl != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(inv.pdfUrl!);
                      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download from Server'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'overdue':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Pending';
    }
  }
}

class _DateRow extends StatelessWidget {
  final String label, value;
  const _DateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
    );
  }
}