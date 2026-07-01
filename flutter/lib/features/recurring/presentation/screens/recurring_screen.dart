import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

final recurringInvoicesProvider = FutureProvider<List<RecurringInvoiceModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('recurring_invoices').select('*, clients(*)').eq('user_id', uid).order('next_date');
  return (data as List).map((j) => RecurringInvoiceModel.fromJson(j)).toList();
});

class RecurringInvoicesScreen extends ConsumerWidget {
  const RecurringInvoicesScreen({super.key});

  String _frequencyLabel(String freq) {
    switch (freq) {
      case 'weekly': return 'Weekly';
      case 'monthly': return 'Monthly';
      case 'quarterly': return 'Quarterly';
      case 'yearly': return 'Yearly';
      default: return freq;
    }
  }

  IconData _frequencyIcon(String freq) {
    switch (freq) {
      case 'weekly': return Icons.calendar_view_week;
      case 'monthly': return Icons.calendar_month;
      case 'quarterly': return Icons.calendar_view_week;
      case 'yearly': return Icons.calendar_today;
      default: return Icons.repeat;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(recurringInvoicesProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');
    final dateFmt = DateFormat('d MMM');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Recurring Invoices'),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recurringInvoicesProvider),
        child: invoices.when(
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.repeat, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('No recurring invoices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Set up automatic invoices for regular clients', style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => context.push('/recurring/add'), child: const Text('Create Recurring')),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final inv = list[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                          child: Icon(_frequencyIcon(inv.frequency), color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(inv.client?.name ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                          Text('Next: ${dateFmt.format(inv.nextDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: inv.status == 'active' ? AppColors.successLight : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                            child: Text(inv.status == 'active' ? 'Active' : 'Paused', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: inv.status == 'active' ? AppColors.success : AppColors.textMuted)),
                          ),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('₹${fmt.format(inv.amount)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          Text(_frequencyLabel(inv.frequency), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ]),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                          onSelected: (v) async {
                            if (v == 'pause') {
                              final supabase = ref.read(supabaseProvider);
                              await supabase.from('recurring_invoices').update({'status': inv.status == 'active' ? 'paused' : 'active'}).eq('id', inv.id);
                              ref.invalidate(recurringInvoicesProvider);
                            } else if (v == 'delete') {
                              final supabase = ref.read(supabaseProvider);
                              await supabase.from('recurring_invoices').delete().eq('id', inv.id);
                              ref.invalidate(recurringInvoicesProvider);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'pause', child: Text(inv.status == 'active' ? 'Pause' : 'Resume')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      ]),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recurring/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Create Recurring Invoice Screen
class CreateRecurringScreen extends ConsumerStatefulWidget {
  const CreateRecurringScreen({super.key});

  @override
  ConsumerState<CreateRecurringScreen> createState() => _CreateRecurringScreenState();
}

class _CreateRecurringScreenState extends ConsumerState<CreateRecurringScreen> {
  ClientModel? _selectedClient;
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  List<ClientModel> _clients = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClients());
  }

  Future<void> _loadClients() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.read(currentUserIdProvider);
      final data = await supabase.from('clients').select().eq('user_id', uid).order('name');
      if (mounted) setState(() => _clients = (data as List).map((j) => ClientModel.fromJson(j)).toList());
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _save() async {
    if (_selectedClient == null || _amountCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.read(currentUserIdProvider);

      DateTime nextDate = _startDate;
      if (_frequency == 'weekly') nextDate = _startDate.add(const Duration(days: 7));
      if (_frequency == 'monthly') nextDate = DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
      if (_frequency == 'quarterly') nextDate = DateTime(_startDate.year, _startDate.month + 3, _startDate.day);
      if (_frequency == 'yearly') nextDate = DateTime(_startDate.year + 1, _startDate.month, _startDate.day);

      await supabase.from('recurring_invoices').insert({
        'user_id': uid,
        'client_id': _selectedClient!.id,
        'items': [{'name': 'Recurring Service', 'quantity': 1, 'price': double.parse(_amountCtrl.text)}],
        'amount': double.parse(_amountCtrl.text),
        'frequency': _frequency,
        'next_date': nextDate.toIso8601String(),
        'status': 'active',
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurring invoice created!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('New Recurring Invoice'),
        backgroundColor: AppColors.surfaceAlt,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              const Text('Client', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              _clients.isEmpty ? const Text('No clients')
                  : DropdownButtonFormField<ClientModel>(
                      value: _selectedClient,
                      hint: const Text('Select'),
                      items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                      onChanged: (c) => setState(() => _selectedClient = c),
                    ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Frequency', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: ['weekly', 'monthly', 'quarterly', 'yearly'].map((f) =>
                ChoiceChip(label: Text(f[0].toUpperCase() + f.substring(1)), selected: _frequency == f, onSelected: (s) => setState(() => _frequency = f))
              ).toList()),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              const Text('Amount', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹ ', hintText: '0.00')),
            ]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loading ? null : _save, child: _loading ? const CircularProgressIndicator() : const Text('Create')),
        ],
      ),
    );
  }
}