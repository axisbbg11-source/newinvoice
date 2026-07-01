import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

final contractsProvider = FutureProvider<List<ContractModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('contracts').select('*, clients(*)').eq('user_id', uid).order('created_at', ascending: false);
  return (data as List).map((j) => ContractModel.fromJson(j)).toList();
});

class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contracts = ref.watch(contractsProvider);
    final fmt = DateFormat('d MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Contracts', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(contractsProvider),
        child: contracts.when(
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
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.description_outlined, size: 36, color: AppColors.success),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No contracts yet',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create contracts for your clients',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/contracts/create'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create Contract'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final contract = list[i];
                    return GestureDetector(
                      onTap: () => context.push('/contracts/${contract.id}'),
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
                                color: _contractColor(contract.contractType).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_contractIcon(contract.contractType), color: _contractColor(contract.contractType), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contract.title,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    contract.client?.name ?? 'Unknown Client',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${fmt.format(contract.startDate)} - ${contract.endDate != null ? fmt.format(contract.endDate!) : 'Ongoing'}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (contract.signed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                    SizedBox(width: 4),
                                    Text('Signed', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.warningLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pending, size: 14, color: AppColors.warning),
                                    SizedBox(width: 4),
                                    Text('Pending', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500)),
                                  ],
                                ),
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
          onPressed: () => context.push('/contracts/create'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  IconData _contractIcon(String type) {
    switch (type) {
      case 'service_agreement':
        return Icons.handshake_outlined;
      case 'freelance_contract':
        return Icons.work_outline;
      case 'nda':
        return Icons.lock_outlined;
      case 'rental_agreement':
        return Icons.home_outlined;
      case 'partnership':
        return Icons.group_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _contractColor(String type) {
    switch (type) {
      case 'service_agreement':
        return AppColors.primary;
      case 'freelance_contract':
        return const Color(0xFF7C3AED);
      case 'nda':
        return AppColors.danger;
      case 'rental_agreement':
        return AppColors.success;
      case 'partnership':
        return const Color(0xFF059669);
      default:
        return AppColors.textSecondary;
    }
  }
}