import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/invoices/presentation/screens/invoices_screen.dart';
import '../../features/invoices/presentation/screens/create_invoice_screen.dart';
import '../../features/invoices/presentation/screens/invoice_detail_screen.dart';
import '../../features/clients/presentation/screens/clients_screen.dart';
import '../../features/clients/presentation/screens/add_client_screen.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/reports/presentation/screens/generate_report_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/contracts/presentation/screens/contracts_screen.dart';
import '../../features/contracts/presentation/screens/create_contract_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/quotes/presentation/screens/quotes_screen.dart';
import '../../features/recurring/presentation/screens/recurring_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/payment/presentation/screens/payment_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/invoices', builder: (c, s) => const InvoicesScreen(),
            routes: [
              GoRoute(path: 'create', builder: (c, s) => const CreateInvoiceScreen()),
              GoRoute(path: ':id', builder: (c, s) => InvoiceDetailScreen(id: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(path: '/clients', builder: (c, s) => const ClientsScreen(),
            routes: [
              GoRoute(path: 'add', builder: (c, s) => AddClientScreen(editId: s.uri.queryParameters['edit'])),
              GoRoute(path: ':id', builder: (c, s) => ClientDetailScreen(id: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(path: '/expenses', builder: (c, s) => const ExpensesScreen(),
            routes: [
              GoRoute(path: 'add', builder: (c, s) => const AddExpenseScreen()),
            ],
          ),
          GoRoute(path: '/reports', builder: (c, s) => const ReportsScreen(),
            routes: [
              GoRoute(path: 'generate', builder: (c, s) => const GenerateReportScreen()),
            ],
          ),
          GoRoute(path: '/ai', builder: (c, s) => const AiAssistantScreen()),
          GoRoute(path: '/contracts', builder: (c, s) => const ContractsScreen(),
            routes: [
              GoRoute(path: 'create', builder: (c, s) => const CreateContractScreen()),
            ],
          ),
          GoRoute(path: '/products', builder: (c, s) => const ProductsScreen(),
            routes: [
              GoRoute(path: 'add', builder: (c, s) => const AddProductScreen()),
            ],
          ),
          GoRoute(path: '/quotes', builder: (c, s) => const QuotesScreen(),
            routes: [
              GoRoute(path: 'create', builder: (c, s) => const CreateQuoteScreen()),
            ],
          ),
          GoRoute(path: '/recurring', builder: (c, s) => const RecurringInvoicesScreen(),
            routes: [
              GoRoute(path: 'add', builder: (c, s) => const CreateRecurringScreen()),
            ],
          ),
          GoRoute(path: '/budgets', builder: (c, s) => const BudgetsScreen()),
        ],
      ),
      GoRoute(path: '/subscription', builder: (c, s) => const SubscriptionScreen()),
      GoRoute(path: '/payment/:invoiceId', builder: (c, s) => PaymentScreen(invoiceId: s.pathParameters['invoiceId']!)),
    ],
  );
});

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _aiPanelOpen = false;

  final _tabs = ['/home', '/invoices', '/clients', '/more'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          // Floating "Ask AI" button - persists across all screens
          Positioned(
            right: 18,
            bottom: 104,
            child: _AIFloatingButton(
              onTap: () {
                setState(() => _aiPanelOpen = !_aiPanelOpen);
              },
            ),
          ),
          // AI Panel
          if (_aiPanelOpen)
            Positioned(
              left: 14,
              right: 14,
              bottom: 104,
              child: _AIPanel(
                onClose: () => setState(() => _aiPanelOpen = false),
              ),
            ),
        ],
      ),
      // Bottom nav with 5 items: Home / Invoices / + / Clients / More
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home tab
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_filled,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onTabTap(0),
                ),
                // Invoices tab
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Invoices',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onTabTap(1),
                ),
                // + button (center, gradient navy)
                _CreateButton(
                  onTap: () {
                    if (_currentIndex == 0 || _currentIndex == 1) {
                      context.push('/invoices/create');
                    } else if (_currentIndex == 2) {
                      context.push('/clients/add');
                    }
                  },
                ),
                // Clients tab
                _NavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Clients',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onTabTap(2),
                ),
                // More tab
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'More',
                  isSelected: _currentIndex == 3,
                  onTap: () {
                    setState(() => _currentIndex = 3);
                    _showMoreDrawer();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 3) {
      // More tab - show drawer instead of navigating
      _showMoreDrawer();
    } else {
      context.go(_tabs[index]);
    }
  }

  void _showMoreDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoreDrawerSheet(
        onNavigate: (path) {
          Navigator.pop(ctx);
          if (path == '/subscription') {
            context.push('/subscription');
          } else {
            context.go(path);
          }
        },
        onLogout: () async {
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// Floating "Ask AI" button - Clean, professional design
class _AIFloatingButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AIFloatingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// AI Panel - bottom sheet with input (Clean design)
class _AIPanel extends StatefulWidget {
  final VoidCallback onClose;

  const _AIPanel({required this.onClose});

  @override
  State<_AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends State<_AIPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AI Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Suggestion text
          const Text(
            'Try: "Which invoices are overdue?" or "Draft a reminder for client invoice."',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Input row
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ask about your business...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// + Create button - Clean, professional design (no neon)
class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.brand,
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandLight : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.brand : AppColors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.brand : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreDrawerSheet extends ConsumerWidget {
  final Function(String) onNavigate;
  final VoidCallback onLogout;

  const _MoreDrawerSheet({
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Container(
      margin: const EdgeInsets.only(top: 100),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Logo
          Image.asset(
            'assets/images/logo.png',
            width: 48,
            height: 48,
          ),
          const SizedBox(height: 8),
          const Text(
            'BizDesk',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Subscription/Plan entry (always visible in More)
          userAsync.when(
            data: (u) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              // Use Material + Ink so ListTile ink splashes are visible over a decorated background
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.accent.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.card_membership, color: AppColors.accent, size: 22),
                    ),
                    title: const Text('Subscription', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text(
                      u?.plan == 'free' ? 'Free Plan - Tap to upgrade' : '${u?.plan ?? "Free"} Plan',
                      style: TextStyle(fontSize: 12, color: u?.plan == 'free' ? AppColors.accent : AppColors.textMuted),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: u?.plan == 'pro' ? AppColors.success : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        u?.plan == 'pro' ? 'PRO' : u?.plan == 'agency' ? 'AGENCY' : 'FREE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: u?.plan == 'free' ? AppColors.textMuted : Colors.white,
                        ),
                      ),
                    ),
                    onTap: () => onNavigate('/subscription'),
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Menu items with sections
          _buildSectionHeader('MANAGE'),
          _DrawerItem(
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.primary,
            title: 'Invoices',
            onTap: () => onNavigate('/invoices'),
          ),
          _DrawerItem(
            icon: Icons.people_outline,
            iconColor: const Color(0xFF7C3AED),
            title: 'Clients',
            onTap: () => onNavigate('/clients'),
          ),
          _DrawerItem(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.danger,
            title: 'Expenses',
            onTap: () => onNavigate('/expenses'),
          ),
          _DrawerItem(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF059669),
            title: 'Contracts',
            onTap: () => onNavigate('/contracts'),
          ),
          _DrawerItem(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF6366F1),
            title: 'Products & Services',
            onTap: () => onNavigate('/products'),
          ),
          _DrawerItem(
            icon: Icons.request_quote_outlined,
            iconColor: AppColors.warning,
            title: 'Quotes',
            onTap: () => onNavigate('/quotes'),
          ),
          _DrawerItem(
            icon: Icons.repeat,
            iconColor: const Color(0xFFEC4899),
            title: 'Recurring Invoices',
            onTap: () => onNavigate('/recurring'),
          ),
          _DrawerItem(
            icon: Icons.savings_outlined,
            iconColor: AppColors.success,
            title: 'Budgets',
            onTap: () => onNavigate('/budgets'),
          ),
          _DrawerItem(
            icon: Icons.auto_awesome,
            iconColor: AppColors.accent,
            title: 'AI Assistant',
            onTap: () => onNavigate('/ai'),
            isHighlighted: true,
          ),

          const SizedBox(height: 8),
          _buildSectionHeader('SUPPORT'),
          _DrawerItem(
            icon: Icons.settings_outlined,
            iconColor: AppColors.textSecondary,
            title: 'Settings',
            onTap: () {},
          ),
          _DrawerItem(
            icon: Icons.help_outline,
            iconColor: AppColors.textSecondary,
            title: 'Help & Support',
            onTap: () {},
          ),

          const Divider(height: 24),
          _DrawerItem(
            icon: Icons.logout,
            iconColor: AppColors.danger,
            title: 'Logout',
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _DrawerItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isHighlighted ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isHighlighted ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                      color: isHighlighted ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}