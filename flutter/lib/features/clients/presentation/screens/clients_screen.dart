import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

// Provider for all clients
final clientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('clients').select().eq('user_id', uid).order('name');
  return (data as List).map((j) => ClientModel.fromJson(j)).toList();
});

// Provider for client with total owed
final clientWithOwedProvider = FutureProvider.family<double, String>((ref, clientId) async {
  final supabase = ref.watch(supabaseProvider);
  final invoices = await supabase.from('invoices').select('total, status').eq('client_id', clientId).or('status.eq.pending,status.eq.overdue');
  double totalOwed = 0;
  for (final inv in invoices) {
    totalOwed += (inv['total'] as num).toDouble();
  }
  return totalOwed;
});

// Provider for filtered clients based on search
final clientSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredClientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  final clients = await ref.watch(clientsProvider.future);
  final query = ref.watch(clientSearchQueryProvider).toLowerCase();
  if (query.isEmpty) return clients;
  return clients.where((c) => c.name.toLowerCase().contains(query)).toList();
});

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(filteredClientsProvider);
    final searchQuery = ref.watch(clientSearchQueryProvider);
    final fmt = NumberFormat('#,##,###', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 52, 20, 16),
              child: Text('Clients', style: AppTextStyles.pageTitle),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => ref.read(clientSearchQueryProvider.notifier).state = v,
                        decoration: const InputDecoration(
                          hintText: 'Search clients...',
                          hintStyle: TextStyle(fontSize: 13.5, color: AppColors.muted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 13.5, color: AppColors.text),
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => ref.read(clientSearchQueryProvider.notifier).state = '',
                        child: const Icon(Icons.clear, size: 18, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
            ),

            // Client list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(clientsProvider);
                  ref.invalidate(filteredClientsProvider);
                },
                child: clients.when(
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
                                    color: AppColors.purpleTint,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.people_outline, size: 36, color: AppColors.purple),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  searchQuery.isNotEmpty ? 'No clients found' : 'No clients yet',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  searchQuery.isNotEmpty ? 'Try a different search term' : 'Add your first client to get started',
                                  style: AppTextStyles.body,
                                  textAlign: TextAlign.center,
                                ),
                                if (searchQuery.isEmpty) ...[
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => context.push('/clients/add'),
                                    icon: const Icon(Icons.person_add, size: 18),
                                    label: const Text('Add Client'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final client = list[i];
                            final owed = ref.watch(clientWithOwedProvider(client.id));

                            return GestureDetector(
                              onTap: () => context.push('/clients/${client.id}'),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
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
                                          client.initials,
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
                                    // Client name and email/phone
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.name,
                                            style: AppTextStyles.cardTitle,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            client.email ?? client.phone ?? '',
                                            style: AppTextStyles.body,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Owed amount chip (if any)
                                    owed.when(
                                      data: (o) => o > 0
                                          ? ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 90),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.amberTint,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '₹${fmt.format(o)}',
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.amber,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                      loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1)),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.rose))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}