import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

class AddClientScreen extends ConsumerStatefulWidget {
  final String? editId;
  const AddClientScreen({super.key, this.editId});

  @override
  ConsumerState<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends ConsumerState<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _whatsappEnabled = false;
  bool _loading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.editId != null && widget.editId!.isNotEmpty;
    if (_isEditMode) {
      _loadClientData();
    }
  }

  Future<void> _loadClientData() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final data = await supabase.from('clients').select().eq('id', widget.editId!).single();
      final client = ClientModel.fromJson(data);
      _nameCtrl.text = client.name;
      _emailCtrl.text = client.email ?? '';
      _phoneCtrl.text = client.phone ?? '';
      _addressCtrl.text = client.address ?? '';
      _whatsappEnabled = client.whatsappEnabled;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading client: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final uid = ref.read(currentUserIdProvider);

      debugPrint('Saving client for user: $uid, editMode: $_isEditMode');

      if (_isEditMode) {
        // Update existing client
        await supabase.from('clients').update({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'whatsapp_enabled': _whatsappEnabled,
        }).eq('id', widget.editId!);

        debugPrint('Client updated');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_nameCtrl.text.trim()} updated!'), backgroundColor: AppColors.success),
          );
          context.pop();
        }
      } else {
        // Add new client
        final result = await supabase.from('clients').insert({
          'user_id': uid,
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'whatsapp_enabled': _whatsappEnabled,
        }).select();

        debugPrint('Client added: $result');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_nameCtrl.text.trim()} added successfully!'), backgroundColor: AppColors.success),
          );
          context.pop();
        }
      }
    } catch (e) {
      debugPrint('Error saving client: $e');
      String msg = e.toString();
      if (msg.contains('foreign key') || msg.contains('violates')) {
        msg = 'Please login to add clients';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg'), backgroundColor: AppColors.danger));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Client' : 'Add Client'),
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.cardDecoration,
              child: Column(
                children: [
                  // Name field
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Client Name *',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  // Email field
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Phone field
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Address field
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // WhatsApp switch
                  SwitchListTile(
                    title: const Text('Enable WhatsApp reminders', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Send automated payment reminders', style: TextStyle(fontSize: 12)),
                    value: _whatsappEnabled,
                    onChanged: (v) => setState(() => _whatsappEnabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Save button (full-width, consistent height)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isEditMode ? 'Update Client' : 'Save Client'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}