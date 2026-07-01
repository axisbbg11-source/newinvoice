import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../auth/auth_provider.dart';

// Dashboard provider
final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

  final invoices = await supabase.from('invoices').select().eq('user_id', uid).gte('created_at', monthStart);
  final expenses = await supabase.from('expenses').select().eq('user_id', uid).gte('date', monthStart);

  double income = 0, owed = 0;
  int overdue = 0, pending = 0;
  for (final inv in invoices) {
    if (inv['status'] == 'paid') income += (inv['total'] as num).toDouble();
    if (inv['status'] == 'pending') { owed += (inv['total'] as num).toDouble(); pending++; }
    if (inv['status'] == 'overdue') { owed += (inv['total'] as num).toDouble(); overdue++; }
  }
  double exp = 0;
  for (final e in expenses) exp += (e['amount'] as num).toDouble();

  return DashboardSummary(totalIncome: income, totalExpenses: exp, profit: income - exp, totalOwed: owed, overdueCount: overdue, pendingCount: pending);
});

// Recent invoices provider
final recentInvoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('invoices').select('*, clients(*)').eq('user_id', uid).order('created_at', ascending: false).limit(5);
  return (data as List).map((j) => InvoiceModel.fromJson(j)).toList();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashboard = ref.watch(dashboardProvider);
    final invoices = ref.watch(recentInvoicesProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(recentInvoicesProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Top bar: avatar + business name + Premium badge + icons
              SliverAppBar(
                floating: true,
                backgroundColor: AppColors.pageBackground,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                expandedHeight: 90,
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 52, 0, 18),
                  child: user.when(
                    data: (u) => Row(
                      children: [
                        // Avatar circle with initial
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.text,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (u?.businessName ?? u?.name ?? 'M').substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        // Business name + Premium badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u?.businessName ?? u?.name ?? 'My Business',
                              style: AppTextStyles.brandName,
                            ),
                            const SizedBox(height: 2),
                            // Premium badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.amberTint,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '✦',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.09,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const Text('My Business'),
                  ),
                ),
                actions: [
                  // Notification icon
                  Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.text,
                      size: 17,
                    ),
                  ),
                  // Profile icon
                  GestureDetector(
                    onTap: () => _showProfileSheet(context, ref),
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.text,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),

              // Balance card (white, bordered, with brand-tint glow)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  decoration: AppColors.cardDecoration,
                  child: Stack(
                    children: [
                      // Brand-tint glow in corner
                      Positioned(
                        right: -40,
                        top: -40,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppColors.brandTint,
                                Colors.transparent,
                              ],
                              radius: 0.72,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total balance', style: AppTextStyles.label),
                            const SizedBox(height: 6),
                            dashboard.when(
                              data: (d) => Text(
                                '₹${fmt.format(d.totalIncome - d.totalExpenses)}',
                                style: AppTextStyles.balanceAmount,
                              ),
                              loading: () => Container(
                                height: 44,
                                width: 140,
                                decoration: BoxDecoration(
                                  color: AppColors.line,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              error: (_, __) => const Text('₹0.00', style: AppTextStyles.balanceAmount),
                            ),
                            const SizedBox(height: 18),
                            // Money in / Money out stats
                            Row(
                              children: [
                                // Money in
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppColors.emeraldTint,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_upward,
                                          color: AppColors.emerald,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Money in', style: AppTextStyles.body.copyWith(fontSize: 11)),
                                          const SizedBox(height: 1),
                                          dashboard.when(
                                            data: (d) => Text(
                                              '₹${fmt.format(d.totalIncome)}',
                                              style: AppTextStyles.statValue,
                                            ),
                                            loading: () => const Text('₹0', style: AppTextStyles.statValue),
                                            error: (_, __) => const Text('₹0', style: AppTextStyles.statValue),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: AppColors.line,
                                ),
                                // Money out
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppColors.roseTint,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_downward,
                                          color: AppColors.rose,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Money out', style: AppTextStyles.body.copyWith(fontSize: 11)),
                                          const SizedBox(height: 1),
                                          dashboard.when(
                                            data: (d) => Text(
                                              '₹${fmt.format(d.totalExpenses)}',
                                              style: AppTextStyles.statValue,
                                            ),
                                            loading: () => const Text('₹0', style: AppTextStyles.statValue),
                                            error: (_, __) => const Text('₹0', style: AppTextStyles.statValue),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Outstanding strip
              SliverToBoxAdapter(
                child: dashboard.when(
                  data: (d) => d.pendingCount > 0 || d.overdueCount > 0
                      ? GestureDetector(
                          onTap: () => context.go('/invoices'),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                            decoration: BoxDecoration(
                              color: AppColors.brandTint,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(11),
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
                                  child: const Icon(
                                    Icons.schedule,
                                    color: AppColors.brand,
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹${fmt.format(d.totalOwed)} outstanding',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '${d.pendingCount + d.overdueCount} invoices awaiting payment',
                                        style: AppTextStyles.body.copyWith(fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Remind all',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // Quick actions grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _QuickActionItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Invoice',
                        color: AppColors.brand,
                        bgColor: AppColors.brandTint,
                        onTap: () => context.push('/invoices/create'),
                      ),
                      _QuickActionItem(
                        icon: Icons.people_outline,
                        label: 'Client',
                        color: AppColors.purple,
                        bgColor: AppColors.purpleTint,
                        onTap: () => context.push('/clients/add'),
                      ),
                      _QuickActionItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Expense',
                        color: AppColors.amber,
                        bgColor: AppColors.amberTint,
                        onTap: () => context.push('/expenses/add'),
                      ),
                      _QuickActionItem(
                        icon: Icons.description_outlined,
                        label: 'Reports',
                        color: AppColors.emerald,
                        bgColor: AppColors.emeraldTint,
                        onTap: () => context.go('/reports'),
                      ),
                    ],
                  ),
                ),
              ),

              // Section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent invoices', style: AppTextStyles.sectionTitle),
                      GestureDetector(
                        onTap: () => context.go('/invoices'),
                        child: Text(
                          'See all',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.emerald,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent invoices list
              SliverToBoxAdapter(
                child: invoices.when(
                  data: (list) => list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: AppColors.cardDecoration,
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  color: AppColors.muted,
                                  size: 36,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No invoices yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create your first invoice to get started',
                                  style: AppTextStyles.body,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: () => context.push('/invoices/create'),
                                  child: const Text('Create invoice'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: list.asMap().entries.map((entry) {
                              final inv = entry.value;
                              return _InvoiceRow(
                                invoice: inv,
                                isLast: entry.key == list.length - 1,
                              );
                            }).toList(),
                          ),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // Bottom padding for FAB and bottom nav
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.only(top: 100),
        decoration: const BoxDecoration(
          color: AppColors.pageBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            // Profile section
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.text,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Business', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('owner@mybusiness.com', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Premium card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brand, AppColors.brandDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.amberTint,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.star,
                      color: AppColors.amber,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You're on Premium",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage plan & billing →',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFAEB5C4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Menu items
            _SheetItem(
              icon: Icons.person_outline,
              title: 'Account settings',
              onTap: () {},
            ),
            _SheetItem(
              icon: Icons.settings_outlined,
              title: 'Preferences',
              onTap: () {},
            ),
            _SheetItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {},
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 8),
            _SheetItem(
              icon: Icons.logout,
              title: 'Log out',
              color: AppColors.rose,
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Quick action item widget
class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// Invoice row widget
class _InvoiceRow extends StatelessWidget {
  final InvoiceModel invoice;
  final bool isLast;

  const _InvoiceRow({required this.invoice, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,###', 'en_IN');
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

    return GestureDetector(
      onTap: () => context.push('/invoices/${invoice.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        child: Row(
          children: [
            // Avatar/initials chip
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
            const SizedBox(width: 12),
            // Client name and due date
            Expanded(
              child: Column(
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
                        : 'Due ${DateFormat('d MMM').format(invoice.dueDate)}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            // Amount and status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fmt.format(invoice.total)}',
                  style: AppTextStyles.amount,
                ),
                const SizedBox(height: 6),
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
          ],
        ),
      ),
    );
  }
}

// Sheet item widget
class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _SheetItem({
    required this.icon,
    required this.title,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppColors.text;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}