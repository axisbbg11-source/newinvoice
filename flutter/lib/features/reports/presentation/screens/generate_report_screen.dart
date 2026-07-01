import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/models.dart';

final reportClientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('clients').select().eq('user_id', uid).order('name');
  return (data as List).map((j) => ClientModel.fromJson(j)).toList();
});

// Provider for work logs
final workLogsProvider = FutureProvider.family<List<WorkLogModel>, String>((ref, clientId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase.from('work_logs').select('*, clients(*)').eq('client_id', clientId).order('date', ascending: false);
  return (data as List).map((j) => WorkLogModel.fromJson(j)).toList();
});

class GenerateReportScreen extends ConsumerStatefulWidget {
  const GenerateReportScreen({super.key});

  @override
  ConsumerState<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends ConsumerState<GenerateReportScreen> {
  ClientModel? _client;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _content;
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  bool _generatingAI = false;

  // Fetch work logs for selected client and period
  Future<List<WorkLogModel>> _fetchWorkLogs() async {
    if (_client == null) return [];
    final supabase = ref.read(supabaseProvider);
    final data = await supabase.from('work_logs')
        .select('*, clients(*)')
        .eq('client_id', _client!.id)
        .gte('date', _startDate.toIso8601String())
        .lte('date', _endDate.toIso8601String())
        .order('date', ascending: false);
    return (data as List).map((j) => WorkLogModel.fromJson(j)).toList();
  }

  Future<void> _generateWithAI() async {
    if (_client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a client')));
      return;
    }
    setState(() => _generatingAI = true);
    try {
      // Fetch data
      final supabase = ref.read(supabaseProvider);
      final uid = ref.watch(currentUserIdProvider);

      final invoices = await supabase.from('invoices')
          .select()
          .eq('user_id', uid)
          .eq('client_id', _client!.id)
          .gte('invoice_date', _startDate.toIso8601String())
          .lte('invoice_date', _endDate.toIso8601String());

      final workLogs = await _fetchWorkLogs();

      double totalInvoiced = 0, totalReceived = 0;
      for (final inv in invoices) {
        totalInvoiced += (inv['total'] as num).toDouble();
        if (inv['status'] == 'paid') totalReceived += (inv['total'] as num).toDouble();
      }

      try {
        final resp = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/api/v1/reports/generate'),
          headers: {'Content-Type': 'application/json'},
          body: '''
          {
            "user_id": "$uid",
            "client_id": "${_client!.id}",
            "client_name": "${_client!.name}",
            "business_name": "Your Business",
            "period_start": "${_startDate.toIso8601String()}",
            "period_end": "${_endDate.toIso8601String()}",
            "work_logs": ${workLogs.map((w) => '"${w.note}"').toList()}
          }
          ''',
        );

        if (resp.statusCode == 200) {
          setState(() {
            _content = _generateLocalReport(totalInvoiced, totalReceived, workLogs);
          });
        } else {
          setState(() {
            _content = _generateLocalReport(totalInvoiced, totalReceived, workLogs);
          });
        }
      } catch (e) {
        // Fallback to local generation
        setState(() {
          _content = _generateLocalReport(totalInvoiced, totalReceived, workLogs);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _generatingAI = false);
  }

  String _generateLocalReport(double totalInvoiced, double totalReceived, List<WorkLogModel> workLogs) {
    return '''
# Work Report: ${_client!.name}
Period: ${DateFormat('d MMM yyyy').format(_startDate)} - ${DateFormat('d MMM yyyy').format(_endDate)}

## Summary
- Total Invoiced: Rs.${totalInvoiced.toStringAsFixed(2)}
- Amount Received: Rs.${totalReceived.toStringAsFixed(2)}
- Outstanding: Rs.${(totalInvoiced - totalReceived).toStringAsFixed(2)}

## Work Completed
${workLogs.isEmpty ? 'No work logs recorded for this period.' : workLogs.map((w) => '- ${w.note}').join('\n')}

## Notes
${_notesCtrl.text.isEmpty ? 'No additional notes.' : _notesCtrl.text}

---
Generated by BizDesk
''';
  }

  Future<void> _save() async {
    if (_content == null || _client == null) return;
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.watch(currentUserIdProvider);
      await supabase.from('reports').insert({
        'user_id': uid,
        'client_id': _client!.id,
        'period_start': _startDate.toIso8601String(),
        'period_end': _endDate.toIso8601String(),
        'content': _content,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report saved')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _loading = false);
  }

  Future<void> _emailToClient() async {
    if (_content == null || _client == null || _client!.email == null) return;
    setState(() => _loading = true);
    try {
      // Call backend to send email
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/v1/reports/send'),
        headers: {'Content-Type': 'application/json'},
        body: '''
        {
          "client_email": "${_client!.email}",
          "client_name": "${_client!.name}",
          "content": "${_content!.replaceAll('"', '\\"')}"
        }
        ''',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent to client!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(reportClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Generate Report'),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step 1: Client selection
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Select Client',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                clients.when(
                  data: (list) => DropdownButtonFormField<ClientModel>(
                    initialValue: _client,
                    decoration: const InputDecoration(
                      labelText: 'Client',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                    items: list.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _client = v),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step 2: Period selection
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Select Period',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _DatePicker(label: 'From', date: _startDate, onChanged: (d) => setState(() => _startDate = d))),
                    const SizedBox(width: 12),
                    Expanded(child: _DatePicker(label: 'To', date: _endDate, onChanged: (d) => setState(() => _endDate = d))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step 3: Additional notes
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '3. Add Notes (Optional)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Any additional notes to include in the report...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Generate buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generatingAI ? null : _generateWithAI,
              icon: _generatingAI
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_generatingAI ? 'Generating with AI...' : 'Generate with AI'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _generateWithAI,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Generate Locally'),
            ),
          ),

          // Preview
          if (_content != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preview',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _content!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 10),
                if (_client?.email != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _emailToClient,
                      icon: const Icon(Icons.mail_outlined, size: 18),
                      label: const Text('Email'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DatePicker({required this.label, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(
          DateFormat('d MMM yyyy').format(date),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}