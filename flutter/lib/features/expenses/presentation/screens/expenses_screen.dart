import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

// Month filter state
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final expensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('expenses').select().eq('user_id', uid).order('date', ascending: false);
  return (data as List).map((j) => ExpenseModel.fromJson(j)).toList();
});

final filteredExpensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final expenses = await ref.watch(expensesProvider.future);
  final selectedMonth = ref.watch(selectedMonthProvider);
  return expenses.where((e) => e.date.year == selectedMonth.year && e.date.month == selectedMonth.month).toList();
});

final monthlyTotalProvider = FutureProvider<double>((ref) async {
  final expenses = await ref.watch(filteredExpensesProvider.future);
  double total = 0.0;
  for (final exp in expenses) {
    total += exp.amount;
  }
  return total;
});

final expensesByCategoryProvider = FutureProvider<Map<String, double>>((ref) async {
  final expenses = await ref.watch(filteredExpensesProvider.future);
  final Map<String, double> categoryTotals = {};
  for (final exp in expenses) {
    categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0) + exp.amount;
  }
  return categoryTotals;
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(filteredExpensesProvider);
    final monthlyTotal = ref.watch(monthlyTotalProvider);
    final categoryTotals = ref.watch(expensesByCategoryProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');
    final monthFmt = DateFormat('MMMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month selector - enhanced
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => ref.read(selectedMonthProvider.notifier).state = DateTime(selectedMonth.year, selectedMonth.month - 1),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_left, color: AppColors.primary, size: 20),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    monthFmt.format(selectedMonth),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(selectedMonthProvider.notifier).state = DateTime(selectedMonth.year, selectedMonth.month + 1),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monthly total card - enhanced gradient
          monthlyTotal.when(
            data: (total) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.danger,
                    AppColors.danger.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total this month', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: 4),
                      Text(
                        '₹${fmt.format(total)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
            loading: () => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 90,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Category breakdown - enhanced chips
          categoryTotals.when(
            data: (cats) => cats.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'By Category',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: cats.entries
                              .map(
                                (e) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _categoryColor(e.key).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _categoryColor(e.key).withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_categoryIcon(e.key), size: 14, color: _categoryColor(e.key)),
                                      const SizedBox(width: 6),
                                      Text(
                                        e.key,
                                        style: TextStyle(fontSize: 12, color: _categoryColor(e.key), fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '₹${fmt.format(e.value)}',
                                        style: TextStyle(fontSize: 12, color: _categoryColor(e.key), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Expenses list - enhanced
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(expensesProvider);
                ref.invalidate(filteredExpensesProvider);
                ref.invalidate(monthlyTotalProvider);
                ref.invalidate(expensesByCategoryProvider);
              },
              child: expenses.when(
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
                                  color: AppColors.dangerLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.account_balance_wallet_outlined, size: 36, color: AppColors.danger),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No expenses in ${monthFmt.format(selectedMonth)}',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              const Text('Track your business expenses', style: TextStyle(fontSize: 14, color: AppColors.textMuted), textAlign: TextAlign.center),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/expenses/add'),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Expense'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final exp = list[i];
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
                                    color: _categoryColor(exp.category).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(_categoryIcon(exp.category), color: _categoryColor(exp.category), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exp.category,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            DateFormat('d MMM yyyy').format(exp.date),
                                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                          if (exp.description != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: AppColors.textMuted,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                exp.description!,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '-₹${fmt.format(exp.amount)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.danger),
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
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Rent':
        return Icons.home_outlined;
      case 'Travel':
        return Icons.flight_outlined;
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Marketing':
        return Icons.campaign_outlined;
      case 'Salary':
        return Icons.people_outline;
      case 'Equipment':
        return Icons.computer_outlined;
      case 'Utilities':
        return Icons.electrical_services;
      case 'Supplies':
        return Icons.inventory_2_outlined;
      case 'Maintenance':
        return Icons.build_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Rent':
        return AppColors.primary;
      case 'Travel':
        return const Color(0xFF7C3AED);
      case 'Food':
        return AppColors.warning;
      case 'Marketing':
        return AppColors.success;
      case 'Salary':
        return AppColors.danger;
      case 'Equipment':
        return const Color(0xFF059669);
      case 'Utilities':
        return const Color(0xFFD97706);
      case 'Supplies':
        return const Color(0xFF6366F1);
      case 'Maintenance':
        return const Color(0xFFEC4899);
      default:
        return AppColors.textSecondary;
    }
  }
}