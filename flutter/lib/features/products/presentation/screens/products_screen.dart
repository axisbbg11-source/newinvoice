import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

final productsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('products').select().eq('user_id', uid).order('name');
  return (data as List).map((j) => ProductModel.fromJson(j)).toList();
});

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Products & Services', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(productsProvider),
        child: products.when(
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
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.primary),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No products yet',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your services for quick invoicing',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/products/add'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Product'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final product = list[i];
                    return Container(
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
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                if (product.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    product.description!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    maxLines: 1,
                                  ),
                                ],
                                if (product.category != null) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      product.category!,
                                      style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (product.price != null)
                            Text(
                              '₹${fmt.format(product.price)}${product.unit != null ? '/${product.unit}' : ''}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_circle_outline, color: AppColors.accent, size: 20),
                          ),
                        ],
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
          onPressed: () => context.push('/products/add'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// Add Product Screen
class AddProductScreen extends ConsumerStatefulWidget {
  final String? editId;
  const AddProductScreen({super.key, this.editId});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.read(currentUserIdProvider);

      await supabase.from('products').insert({
        'user_id': uid,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'price': _priceCtrl.text.isEmpty ? null : double.parse(_priceCtrl.text),
        'unit': _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        'category': _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added!')));
        context.pop();
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
        title: const Text('Add Product/Service', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close, color: AppColors.textPrimary),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Product/Service Name *',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(color: AppColors.textPrimary),
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      hintText: 'hour, piece',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6)),
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryCtrl,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Consulting, Design',
                  hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6)),
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Product'),
            ),
          ),
        ],
      ),
    );
  }
}