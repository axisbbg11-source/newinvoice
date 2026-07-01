import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/models.dart';

final budgetsProvider = FutureProvider<List<ExpenseBudgetModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('expense_budgets').select().eq('user_id', uid).order('month', ascending: false);
  return (data as List).map((j) => ExpenseBudgetModel.fromJson(j)).toList();
});

final currentMonthExpensesProvider = FutureProvider<Map<String, double>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
  final endOfMonth = DateTime(now.year, now.month + 1, 0).toIso8601String();

  final data = await supabase.from('expenses').select('category, amount').eq('user_id', uid).gte('date', startOfMonth).lte('date', endOfMonth);

  Map<String, double> totals = {};
  for (final exp in data) {
    totals[exp['category']] = (totals[exp['category']] ?? 0) + (exp['amount'] as num).toDouble();
  }
  return totals;
});

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    final expenses = ref.watch(currentMonthExpensesProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');
    final monthFmt = DateFormat('MMMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Expense Budgets'),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
      ),
      body: budgets.when(
        data: (list) {
          final currentMonth = DateTime.now();
          final currentBudgets = list.where((b) => b.month.year == currentMonth.year && b.month.month == currentMonth.month).toList();
          final expenseData = expenses.valueOrNull ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current Month Overview
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(monthFmt.format(currentMonth), style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Budget Set', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('₹${fmt.format(currentBudgets.fold(0.0, (sum, b) => sum + b.amount))}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Spent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('₹${fmt.format(expenseData.values.fold(0.0, (sum, v) => sum + v))}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                  ]),
                  if (currentBudgets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (expenseData.values.fold(0.0, (sum, v) => sum + v) / currentBudgets.fold(0.0, (sum, b) => sum + b.amount)).clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(
                        (expenseData.values.fold(0.0, (sum, v) => sum + v) / currentBudgets.fold(0.0, (sum, b) => sum + b.amount)) > 0.9 ? AppColors.danger : Colors.white,
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 24),

              // Budget by Category
              const Text('Budget by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              if (currentBudgets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text('No budgets set for this month', style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => _showAddBudgetDialog(context, ref), child: const Text('Set Budget')),
                  ]),
                )
              else
                ...currentBudgets.map((budget) {
                  final spent = expenseData[budget.category] ?? 0;
                  final percent = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
                  final isOver = spent > budget.amount;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(budget.category, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('₹${fmt.format(spent)} / ₹${fmt.format(budget.amount)}', style: TextStyle(color: isOver ? AppColors.danger : AppColors.textMuted)),
                      ]),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: percent,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(isOver ? AppColors.danger : AppColors.primary),
                      ),
                      if (isOver) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Over budget by ₹${fmt.format(spent - budget.amount)}', style: const TextStyle(color: AppColors.danger, fontSize: 12))),
                    ]),
                  );
                }),

              const SizedBox(height: 24),
              OutlinedButton.icon(onPressed: () => _showAddBudgetDialog(context, ref), icon: const Icon(Icons.add), label: const Text('Add Budget Category')),
              const SizedBox(height: 80),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, WidgetRef ref) {
    String? selectedCategory;
    final amountCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Set Budget'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Category'),
          items: AppConstants.expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => selectedCategory = v,
        ),
        const SizedBox(height: 16),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget Amount', prefixText: '₹ ')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (selectedCategory == null || amountCtrl.text.isEmpty) return;
          final supabase = ref.read(supabaseProvider);
          final uid = ref.read(currentUserIdProvider);
          final now = DateTime.now();

          await supabase.from('expense_budgets').insert({
            'user_id': uid,
            'category': selectedCategory,
            'amount': double.parse(amountCtrl.text),
            'month': DateTime(now.year, now.month, 1).toIso8601String(),
          });

          ref.invalidate(budgetsProvider);
          if (context.mounted) Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    ));
  }
}