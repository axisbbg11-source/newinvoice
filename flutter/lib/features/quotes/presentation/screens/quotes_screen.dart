import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

final quotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('quotes').select('*, clients(*)').eq('user_id', uid).order('created_at', ascending: false);
  return (data as List).map((j) => QuoteModel.fromJson(j)).toList();
});

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      case 'sent':
        return AppColors.primary;
      case 'converted':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'sent':
        return 'Sent';
      case 'converted':
        return 'Converted';
      default:
        return 'Draft';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'sent':
        return Icons.send;
      case 'converted':
        return Icons.swap_horiz;
      default:
        return Icons.edit_note;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(quotesProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');
    final dateFmt = DateFormat('d MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Quotes & Estimates', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(quotesProvider),
        child: quotes.when(
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
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.request_quote_outlined, size: 36, color: AppColors.warning),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No quotes yet',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create quotes for your clients',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/quotes/create'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create Quote'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final quote = list[i];
                    return GestureDetector(
                      onTap: () => context.push('/quotes/${quote.id}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _statusColor(quote.status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_statusIcon(quote.status), color: _statusColor(quote.status), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quote.quoteNumber,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    quote.client?.name ?? 'Unknown Client',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateFmt.format(quote.createdAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${fmt.format(quote.total)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(quote.status).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(quote.status),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _statusColor(quote.status)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.push('/quotes/create'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// Create Quote Screen - simplified for brevity
class CreateQuoteScreen extends ConsumerStatefulWidget {
  const CreateQuoteScreen({super.key});

  @override
  ConsumerState<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends ConsumerState<CreateQuoteScreen> {
  ClientModel? _selectedClient;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  final _notesCtrl = TextEditingController();
  final _items = <_ItemEntry>[_ItemEntry()];
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
    } catch (e) {
      debugPrint('Error loading clients: $e');
    }
  }

  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  Future<void> _save() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a client')));
      return;
    }
    if (_items.any((i) => i.name.isEmpty || i.price <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill in all item details')));
      return;
    }
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.watch(currentUserIdProvider);
      await supabase.from('quotes').insert({
        'user_id': uid,
        'client_id': _selectedClient!.id,
        'items': _items.map((i) => i.toJson()).toList(),
        'total': _total,
        'status': 'draft',
        'valid_until': _validUntil.toIso8601String(),
        'notes': _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      });

      if (mounted) {
        context.go('/quotes');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote created!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,###', 'en_IN');
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('New Quote', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close, color: AppColors.textPrimary),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              _clients.isEmpty
                  ? TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add a client first'), onPressed: () => context.push('/clients/add'))
                  : DropdownButtonFormField<ClientModel>(
                      initialValue: _selectedClient,
                      hint: const Text('Select client'),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline, size: 18)),
                      items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                      onChanged: (c) => setState(() => _selectedClient = c),
                    ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Valid Until', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _validUntil, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _validUntil = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(DateFormat('d MMM yyyy').format(_validUntil), style: const TextStyle(fontSize: 14)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              ..._items.asMap().entries.map((e) => _ItemRow(entry: e.value, index: e.key, onChanged: () => setState(() {}), onRemove: _items.length > 1 ? () => setState(() => _items.removeAt(e.key)) : null)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _items.add(_ItemEntry())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add item'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44), textStyle: const TextStyle(fontSize: 13)),
              ),
              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('₹${fmt.format(_total)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ItemEntry {
  String name = '';
  int quantity = 1;
  double price = 0;
  double get total => quantity * price;
  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity, 'price': price};
}

class _ItemRow extends StatelessWidget {
  final _ItemEntry entry;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  const _ItemRow({required this.entry, required this.index, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: TextField(
          decoration: const InputDecoration(hintText: 'Item name', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          style: const TextStyle(fontSize: 13),
          onChanged: (v) { entry.name = v; onChanged(); },
        )),
        const SizedBox(width: 8),
        SizedBox(width: 50, child: TextField(
          decoration: const InputDecoration(hintText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          onChanged: (v) { entry.quantity = int.tryParse(v) ?? 1; onChanged(); },
        )),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: TextField(
          decoration: const InputDecoration(hintText: '₹', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          onChanged: (v) { entry.price = double.tryParse(v) ?? 0; onChanged(); },
        )),
        if (onRemove != null) IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted), onPressed: onRemove, padding: const EdgeInsets.all(4)),
      ]),
    );
  }
}