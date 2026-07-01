import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = AppConstants.expenseCategories.first;
  DateTime _date = DateTime.now();
  XFile? _receipt;
  bool _loading = false;
  bool _uploading = false;

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (img != null) setState(() => _receipt = img);
  }

  Future<String?> _uploadReceipt() async {
    if (_receipt == null) return null;
    setState(() => _uploading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.watch(currentUserIdProvider);
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Read file bytes
      final bytes = await _receipt!.readAsBytes();

      // Upload to Supabase Storage using uploadBinary
      await supabase.storage.from('bizdesk-files').uploadBinary(
            'receipts/$fileName',
            bytes,
          );

      // Get public URL
      final url = supabase.storage.from('bizdesk-files').getPublicUrl('receipts/$fileName');
      setState(() => _uploading = false);
      return url;
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading receipt: $e')));
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.watch(currentUserIdProvider);

      // Upload receipt if selected
      String? receiptUrl;
      if (_receipt != null) {
        receiptUrl = await _uploadReceipt();
      }

      await supabase.from('expenses').insert({
        'user_id': uid,
        'amount': double.parse(_amountCtrl.text),
        'category': _category,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'date': _date.toIso8601String(),
        'receipt_url': receiptUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Expense details card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.cardDecoration,
              child: Column(
                children: [
                  // Amount field
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee_outlined, size: 18),
                    ),
                    validator: (v) => v!.isEmpty ? 'Amount is required' : null,
                  ),
                  const SizedBox(height: 14),
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined, size: 18),
                    ),
                    items: AppConstants.expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 14),
                  // Description field
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date picker
                  ListTile(
                    tileColor: AppColors.surface,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 18),
                    ),
                    title: const Text('Date', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    subtitle: Text(
                      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Receipt upload card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receipt (optional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  if (_receipt != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_receipt!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _receipt = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickReceipt(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickReceipt(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Save button (full-width, consistent height)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading || _uploading ? null : _save,
                child: _loading || _uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}