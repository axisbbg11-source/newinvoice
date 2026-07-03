import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/models.dart';

final contractClientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final uid = ref.watch(currentUserIdProvider);
  final data = await supabase.from('clients').select().eq('user_id', uid).order('name');
  return (data as List).map((j) => ClientModel.fromJson(j)).toList();
});

class CreateContractScreen extends ConsumerStatefulWidget {
  const CreateContractScreen({super.key});

  @override
  ConsumerState<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends ConsumerState<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  ClientModel? _client;
  Map<String, String>? _selectedType;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _loading = false;
  String? _generatedContent;

  @override
  void initState() {
    super.initState();
    _selectedType = AppConstants.contractTypes.isNotEmpty
        ? Map<String, String>.from(AppConstants.contractTypes.first)
        : null;
  }

  String _generateContractContent() {
    final client = _client;
    final type = _selectedType;
    final fmt = DateFormat('d MMM yyyy');
    final currencyFmt = NumberFormat('#,##,###', 'en_IN');

    if (type == null || client == null) return '';

    final value = _valueCtrl.text.isNotEmpty ? 'Rs.${currencyFmt.format(double.tryParse(_valueCtrl.text) ?? 0)}' : 'As agreed';

    switch (type['id']) {
      case 'service_agreement':
        return '''
SERVICE AGREEMENT

This Service Agreement ("Agreement") is entered into on ${fmt.format(_startDate)}

BETWEEN:
Service Provider: Your Business Name
Client: ${client.name}
${client.address != null ? 'Address: ${client.address}' : ''}
${client.email != null ? 'Email: ${client.email}' : ''}

1. SERVICES
The Service Provider agrees to provide services as discussed and agreed upon between both parties.

2. PAYMENT
The Client agrees to pay $value for the services rendered. Payment terms: As per invoice.

3. TERM
This agreement begins on ${fmt.format(_startDate)} ${_endDate != null ? 'and ends on ${fmt.format(_endDate!)}' : 'and continues until terminated by either party with 30 days notice'}.

4. CONFIDENTIALITY
Both parties agree to maintain confidentiality of any proprietary information shared.

5. TERMINATION
Either party may terminate this agreement with 30 days written notice.

${_termsCtrl.text.isNotEmpty ? '6. ADDITIONAL TERMS\n${_termsCtrl.text}' : ''}

---

SIGNATURES:

Service Provider: _______________________ Date: ____________

Client: _______________________ Date: ____________
''';

      case 'freelance_contract':
        return '''
FREELANCE CONTRACT

This Freelance Contract ("Contract") is entered into on ${fmt.format(_startDate)}

BETWEEN:
Freelancer: Your Business Name
Client: ${client.name}

1. SCOPE OF WORK
The Freelancer agrees to provide services as mutually agreed upon.

2. COMPENSATION
Total compensation: $value

3. PAYMENT SCHEDULE
Payment due within 30 days of invoice date.

4. INDEPENDENT CONTRACTOR
The Freelancer is an independent contractor, not an employee.

5. INTELLECTUAL PROPERTY
All work product created belongs to the Client upon full payment.

6. TERM
${_endDate != null ? 'This contract runs from ${fmt.format(_startDate)} to ${fmt.format(_endDate!)}.' : 'This is an ongoing contract.'}

${_termsCtrl.text.isNotEmpty ? '7. ADDITIONAL TERMS\n${_termsCtrl.text}' : ''}

---

SIGNATURES:

Freelancer: _______________________ Date: ____________

Client: _______________________ Date: ____________
''';

      case 'nda':
        return '''
NON-DISCLOSURE AGREEMENT (NDA)

This NDA is entered into on ${fmt.format(_startDate)}

BETWEEN:
Disclosing Party: Your Business Name
Receiving Party: ${client.name}

1. DEFINITION OF CONFIDENTIAL INFORMATION
"Confidential Information" means any data or information that is proprietary to the Disclosing Party.

2. OBLIGATIONS
The Receiving Party agrees to:
- Keep all confidential information strictly confidential
- Not disclose to any third party without written consent
- Use only for the intended purpose

3. TERM
This NDA remains in effect for 2 years from the date of signing.

4. GOVERNING LAW
This agreement is governed by applicable laws.

${_termsCtrl.text.isNotEmpty ? '\n5. ADDITIONAL TERMS\n${_termsCtrl.text}' : ''}

---

SIGNATURES:

Disclosing Party: _______________________ Date: ____________

Receiving Party: _______________________ Date: ____________
''';

      default:
        return '''
CONTRACT AGREEMENT

Date: ${fmt.format(_startDate)}

Party 1: Your Business Name
Party 2: ${client.name}

Terms:
${_termsCtrl.text.isEmpty ? 'Standard terms apply.' : _termsCtrl.text}

---

Signatures:

Party 1: _______________________ Date: ____________

Party 2: _______________________ Date: ____________
''';
    }
  }

  Future<void> _generatePreview() async {
    if (_client == null || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a client and contract type')));
      return;
    }
    setState(() => _generatedContent = _generateContractContent());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_client == null || _selectedType == null) return;
    if (_generatedContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please generate preview first')));
      return;
    }
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.read(currentUserIdProvider);

      await supabase.from('contracts').insert({
        'user_id': uid,
        'client_id': _client!.id,
        'contract_type': _selectedType!['id'],
        'title': _titleCtrl.text.trim(),
        'content': _generatedContent,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate?.toIso8601String(),
        'value': _valueCtrl.text.isEmpty ? null : _valueCtrl.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract saved')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _sharePdf() async {
    if (_generatedContent == null || _client == null) return;
    // For now, share as text. PDF generation can be added later.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract ready to share. Generate preview first.')));
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(contractClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('New Contract'),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(onPressed: _loading ? null : _save, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Contract Type
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Contract Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: AppConstants.contractTypes.map((type) {
                  final isSelected = _selectedType?['id'] == type['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = Map<String, String>.from(type)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryLight : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(type['label']!, style: TextStyle(fontSize: 13, color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal)),
                    ),
                  );
                }).toList()),
              ]),
            ),
            const SizedBox(height: 16),

            // Client
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Client', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                clients.when(
                  data: (list) => list.isEmpty
                      ? TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add a client first'), onPressed: () => context.push('/clients/add'))
                      : DropdownButtonFormField<ClientModel>(
                          initialValue: _client,
                          hint: const Text('Select client'),
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline, size: 18)),
                          items: list.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                          onChanged: (c) => setState(() => _client = c),
                        ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Title & Value
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
              child: Column(children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Contract Title *', hintText: 'e.g., Website Development Agreement'),
                  validator: (v) => v!.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Contract Value (optional)', prefixText: 'Rs. '),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Dates
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _DatePicker(label: 'Start Date', date: _startDate, onChanged: (d) => setState(() => _startDate = d ?? _startDate))),
                  const SizedBox(width: 12),
                  Expanded(child: _DatePicker(label: 'End Date (optional)', date: _endDate, onChanged: (d) => setState(() => _endDate = d), allowNull: true)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Terms
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Additional Terms (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termsCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Any specific terms or conditions...', alignLabelWithHint: true),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Generate button
            ElevatedButton.icon(
              onPressed: _generatePreview,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate Contract'),
            ),
            const SizedBox(height: 16),

            // Preview
            if (_generatedContent != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(_generatedContent!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                )),
              ]),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;
  final bool allowNull;

  const _DatePicker({required this.label, required this.date, required this.onChanged, this.allowNull = false});

  @override
  Widget build(BuildContext context) {
    final effectiveDate = date ?? DateTime.now();
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: effectiveDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(date != null ? DateFormat('d MMM yyyy').format(date!) : 'Select', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ]),
      ),
    );
  }
}