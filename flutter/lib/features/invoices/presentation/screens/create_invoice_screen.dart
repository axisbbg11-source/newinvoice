import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../auth/auth_provider.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  ClientModel? _selectedClient;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  final _notesCtrl = TextEditingController();
  final _items = <_ItemEntry>[_ItemEntry()];
  bool _loading = false;
  List<ClientModel> _clients = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
    });
  }

  Future<void> _loadClients() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.read(currentUserIdProvider);

      if (uid.isEmpty || uid == AppConstants.testUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to create invoices')),
          );
        }
        return;
      }

      final data = await supabase.from('clients').select().eq('user_id', uid).order('name');
      if (mounted) {
        setState(() => _clients = (data as List).map((j) => ClientModel.fromJson(j)).toList());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: $e')),
        );
      }
    }
  }

  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  Future<void> _submit() async {
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
      await supabase.from('invoices').insert({
        'user_id': uid,
        'client_id': _selectedClient!.id,
        'items': _items.map((i) => i.toJson()).toList(),
        'total': _total,
        'status': 'pending',
        'invoice_date': _invoiceDate.toIso8601String(),
        'due_date': _dueDate.toIso8601String(),
        'notes': _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      });

      if (!mounted) return;
      context.go('/invoices');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice created and sent!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,###', 'en_IN');
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => context.go('/invoices'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.text, size: 16),
                    ),
                  ),
                  // Title
                  Text('New invoice', style: AppTextStyles.formTitle),
                  // Send button
                  GestureDetector(
                    onTap: _loading ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _loading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Send', style: AppTextStyles.button),
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client field
                    Text('Client', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: _clients.isEmpty
                          ? GestureDetector(
                              onTap: () => context.push('/clients/add'),
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: AppColors.muted, size: 15),
                                  const SizedBox(width: 8),
                                  Text('Add a client first', style: AppTextStyles.body.copyWith(color: AppColors.muted)),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Icon(Icons.person_outline, color: AppColors.muted, size: 15),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButton<ClientModel>(
                                    value: _selectedClient,
                                    hint: Text('Select client', style: AppTextStyles.body.copyWith(color: AppColors.muted)),
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    icon: Icon(Icons.expand_more, color: AppColors.muted, size: 15),
                                    items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                                    onChanged: (c) => setState(() => _selectedClient = c),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Dates field
                    Text('Dates', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Invoice date', style: AppTextStyles.body.copyWith(fontSize: 11)),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(context: context, initialDate: _invoiceDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                    if (picked != null) setState(() => _invoiceDate = picked);
                                  },
                                  child: Row(
                                    children: [
                                      Text('📅 ', style: TextStyle(fontSize: 13)),
                                      Text(DateFormat('d MMM yyyy').format(_invoiceDate), style: const TextStyle(fontSize: 13, color: AppColors.text)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Due date', style: AppTextStyles.body.copyWith(fontSize: 11)),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                    if (picked != null) setState(() => _dueDate = picked);
                                  },
                                  child: Row(
                                    children: [
                                      Text('📅 ', style: TextStyle(fontSize: 13)),
                                      Text(DateFormat('d MMM yyyy').format(_dueDate), style: const TextStyle(fontSize: 13, color: AppColors.text)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items field
                    Text('Items', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          ..._items.asMap().entries.map(
                                (e) => _ItemRow(
                                  entry: e.value,
                                  index: e.key,
                                  onChanged: () => setState(() {}),
                                  onRemove: _items.length > 1 ? () => setState(() => _items.removeAt(e.key)) : null,
                                ),
                              ),
                          const SizedBox(height: 8),
                          // Add item button (dashed border)
                          GestureDetector(
                            onTap: () => setState(() => _items.add(_ItemEntry())),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+ Add item',
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Total row
                          Container(
                            padding: const EdgeInsets.only(top: 12),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.line)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                                Text('₹${fmt.format(_total)}', style: AppTextStyles.totalAmount),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes field
                    Text('Notes (optional)', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Payment terms, thank you note...',
                          hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 13, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Item name',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                entry.name = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Qty',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                entry.quantity = int.tryParse(v) ?? 1;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              decoration: InputDecoration(
                hintText: '₹ Price',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                entry.price = double.tryParse(v) ?? 0;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}