import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_provider.dart';

class _Message {
  final String role, content;
  const _Message({required this.role, required this.content});
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_Message>[];
  bool _loading = false;

  final _suggestions = [
    'Who owes me the most?',
    'How much did I earn this month?',
    'Draft a quote for a client',
    'Which expenses are highest?',
  ];

  Future<String> _fetchContext() async {
    final supabase = ref.read(supabaseProvider);
    final uid = ref.watch(currentUserIdProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

    final invoices = await supabase.from('invoices').select('*, clients(name)').eq('user_id', uid).gte('created_at', monthStart);
    final expenses = await supabase.from('expenses').select().eq('user_id', uid).gte('date', monthStart);
    final user = await supabase.from('users').select().eq('id', uid).single();

    double income = 0, totalExpenses = 0, owed = 0;
    final overdueClients = <String>[];
    for (final inv in invoices) {
      if (inv['status'] == 'paid') income += (inv['total'] as num).toDouble();
      if (inv['status'] == 'pending' || inv['status'] == 'overdue') {
        owed += (inv['total'] as num).toDouble();
        if (inv['status'] == 'overdue') overdueClients.add('${inv['clients']?['name'] ?? 'Unknown'} owes ₹${inv['total']}');
      }
    }
    for (final e in expenses) {
      totalExpenses += (e['amount'] as num).toDouble();
    }

    return '''
Business: ${user['business_name'] ?? user['name']}
This month:
- Income collected: ₹$income
- Total expenses: ₹$totalExpenses
- Profit: ₹${income - totalExpenses}
- Total owed to you: ₹$owed
- Overdue clients: ${overdueClients.isEmpty ? 'None' : overdueClients.join(', ')}
- Total invoices this month: ${invoices.length}
''';
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final userMsg = _Message(role: 'user', content: text.trim());
    setState(() {
      _messages.add(userMsg);
      _loading = true;
    });
    _ctrl.clear();
    _scrollDown();

    try {
      // Get business context for AI
      final context = await _fetchContext();

      // Call our backend API (keeps API key server-side)
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/v1/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'context': context,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['response'] != null) {
        setState(() => _messages.add(_Message(role: 'assistant', content: data['response'])));
      } else {
        setState(() => _messages.add(_Message(role: 'assistant', content: data['error'] ?? 'Sorry, something went wrong.')));
      }
    } catch (e) {
      setState(() => _messages.add(const _Message(role: 'assistant', content: 'Sorry, I could not connect right now. Please check your internet connection.')));
    }
    setState(() => _loading = false);
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  'Powered by Groq · Llama 3.3 70B',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted.withValues(alpha: 0.8), fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(suggestions: _suggestions, onTap: _send)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) return const _TypingBubble();
                      final msg = _messages[i];
                      return _ChatBubble(message: msg);
                    },
                  ),
          ),
          _InputBar(controller: _ctrl, loading: _loading, onSend: _send),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _EmptyState({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ask me anything about your business',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'I know your invoices, expenses, and clients',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ...suggestions.asMap().entries.map(
            (entry) => GestureDetector(
              onTap: () => onTap(entry.value),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          border: isUser ? null : Border.all(color: AppColors.border, width: 0.5),
          boxShadow: isUser
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : AppColors.textPrimary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 200),
            SizedBox(width: 4),
            _Dot(delay: 400),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
        ),
      );
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onSend;

  const _InputBar({required this.controller, required this.loading, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Ask anything about your business...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: onSend,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading ? null : () => onSend(controller.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: loading
                      ? [AppColors.border, AppColors.border]
                      : [AppColors.accent, AppColors.accent.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: loading
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: loading
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.arrow_upward, color: Colors.white, size: 20, weight: 600),
            ),
          ),
        ],
      ),
    );
  }
}