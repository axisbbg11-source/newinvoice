// ── User ──────────────────────────────────────────────
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? businessName;
  final String? logoUrl;
  final String? address;
  final String plan; // free | pro | agency
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.businessName,
    this.logoUrl,
    this.address,
    this.plan = 'free',
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'],
        businessName: j['business_name'],
        logoUrl: j['logo_url'],
        address: j['address'],
        plan: j['plan'] ?? 'free',
        createdAt: DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'business_name': businessName,
        'logo_url': logoUrl,
        'address': address,
        'plan': plan,
      };

  UserModel copyWith({String? name, String? phone, String? businessName, String? logoUrl, String? address, String? plan}) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        businessName: businessName ?? this.businessName,
        logoUrl: logoUrl ?? this.logoUrl,
        address: address ?? this.address,
        plan: plan ?? this.plan,
        createdAt: createdAt,
      );
}

// ── Client ─────────────────────────────────────────────
class ClientModel {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final bool whatsappEnabled;
  final String? address;
  final DateTime createdAt;

  const ClientModel({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.whatsappEnabled = false,
    this.address,
    required this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> j) => ClientModel(
        id: j['id'],
        userId: j['user_id'],
        name: j['name'],
        email: j['email'],
        phone: j['phone'],
        whatsappEnabled: j['whatsapp_enabled'] ?? false,
        address: j['address'],
        createdAt: DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'whatsapp_enabled': whatsappEnabled,
        'address': address,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ── Invoice Item ───────────────────────────────────────
class InvoiceItem {
  final String name;
  final int quantity;
  final double price;

  const InvoiceItem({required this.name, required this.quantity, required this.price});

  double get total => quantity * price;

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        name: j['name'],
        quantity: j['quantity'],
        price: (j['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity, 'price': price};
}

// ── Invoice ────────────────────────────────────────────
class InvoiceModel {
  final String id;
  final String userId;
  final String clientId;
  final ClientModel? client;
  final List<InvoiceItem> items;
  final double total;
  final String status; // pending | paid | overdue
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String? pdfUrl;
  final String? notes;
  final DateTime? lastFollowupAt;
  final DateTime createdAt;

  const InvoiceModel({
    required this.id,
    required this.userId,
    required this.clientId,
    this.client,
    required this.items,
    required this.total,
    required this.status,
    required this.invoiceDate,
    required this.dueDate,
    this.pdfUrl,
    this.notes,
    this.lastFollowupAt,
    required this.createdAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> j) => InvoiceModel(
        id: j['id'],
        userId: j['user_id'],
        clientId: j['client_id'],
        client: j['clients'] != null ? ClientModel.fromJson(j['clients']) : null,
        items: (j['items'] as List).map((i) => InvoiceItem.fromJson(i)).toList(),
        total: (j['total'] as num).toDouble(),
        status: j['status'],
        invoiceDate: DateTime.parse(j['invoice_date']),
        dueDate: DateTime.parse(j['due_date']),
        pdfUrl: j['pdf_url'],
        notes: j['notes'],
        lastFollowupAt: j['last_followup_at'] != null ? DateTime.parse(j['last_followup_at']) : null,
        createdAt: DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'client_id': clientId,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'status': status,
        'invoice_date': invoiceDate.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'notes': notes,
      };

  bool get isOverdue => status == 'overdue' || (status == 'pending' && dueDate.isBefore(DateTime.now()));
  int get daysOverdue => DateTime.now().difference(dueDate).inDays;
  String get invoiceNumber => 'INV-${id.substring(0, 6).toUpperCase()}';
}

// ── Expense ────────────────────────────────────────────
class ExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String? description;
  final String? receiptUrl;
  final DateTime date;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.description,
    this.receiptUrl,
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> j) => ExpenseModel(
        id: j['id'],
        userId: j['user_id'],
        amount: (j['amount'] as num).toDouble(),
        category: j['category'],
        description: j['description'],
        receiptUrl: j['receipt_url'],
        date: DateTime.parse(j['date']),
        createdAt: DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'amount': amount,
        'category': category,
        'description': description,
        'receipt_url': receiptUrl,
        'date': date.toIso8601String(),
      };
}

// ── Work Log ───────────────────────────────────────────
class WorkLogModel {
  final String id;
  final String userId;
  final String clientId;
  final ClientModel? client;
  final String note;
  final double? hours;
  final DateTime date;

  const WorkLogModel({
    required this.id,
    required this.userId,
    required this.clientId,
    this.client,
    required this.note,
    this.hours,
    required this.date,
  });

  factory WorkLogModel.fromJson(Map<String, dynamic> j) => WorkLogModel(
        id: j['id'],
        userId: j['user_id'],
        clientId: j['client_id'],
        client: j['clients'] != null ? ClientModel.fromJson(j['clients']) : null,
        note: j['note'],
        hours: j['hours'] != null ? (j['hours'] as num).toDouble() : null,
        date: DateTime.parse(j['date']),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'client_id': clientId,
        'note': note,
        'hours': hours,
        'date': date.toIso8601String(),
      };
}

// ── Report ─────────────────────────────────────────────
class ReportModel {
  final String id;
  final String userId;
  final String clientId;
  final ClientModel? client;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? content;
  final String? pdfUrl;
  final DateTime? sentAt;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.userId,
    required this.clientId,
    this.client,
    required this.periodStart,
    required this.periodEnd,
    this.content,
    this.pdfUrl,
    this.sentAt,
    required this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> j) => ReportModel(
        id: j['id'],
        userId: j['user_id'],
        clientId: j['client_id'],
        client: j['clients'] != null ? ClientModel.fromJson(j['clients']) : null,
        periodStart: DateTime.parse(j['period_start']),
        periodEnd: DateTime.parse(j['period_end']),
        content: j['content'],
        pdfUrl: j['pdf_url'],
        sentAt: j['sent_at'] != null ? DateTime.parse(j['sent_at']) : null,
        createdAt: DateTime.parse(j['created_at']),
      );
}

// ── Dashboard Summary ──────────────────────────────────
class DashboardSummary {
  final double totalIncome;
  final double totalExpenses;
  final double profit;
  final double totalOwed;
  final int overdueCount;
  final int pendingCount;

  const DashboardSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.profit,
    required this.totalOwed,
    required this.overdueCount,
    required this.pendingCount,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
        totalIncome: (j['total_income'] as num).toDouble(),
        totalExpenses: (j['total_expenses'] as num).toDouble(),
        profit: (j['profit'] as num).toDouble(),
        totalOwed: (j['total_owed'] as num).toDouble(),
        overdueCount: j['overdue_count'],
        pendingCount: j['pending_count'],
      );
}

// ── Contract ─────────────────────────────────────────────
class ContractModel {
  final String id;
  final String userId;
  final String clientId;
  final ClientModel? client;
  final String contractType;
  final String title;
  final String? content;
  final String? pdfUrl;
  final DateTime startDate;
  final DateTime? endDate;
  final String? value;
  final bool signed;
  final DateTime createdAt;

  const ContractModel({
    required this.id,
    required this.userId,
    required this.clientId,
    this.client,
    required this.contractType,
    required this.title,
    this.content,
    this.pdfUrl,
    required this.startDate,
    this.endDate,
    this.value,
    this.signed = false,
    required this.createdAt,
  });

  factory ContractModel.fromJson(Map<String, dynamic> j) => ContractModel(
        id: j['id'],
        userId: j['user_id'],
        clientId: j['client_id'],
        client: j['clients'] != null ? ClientModel.fromJson(j['clients']) : null,
        contractType: j['contract_type'],
        title: j['title'],
        content: j['content'],
        pdfUrl: j['pdf_url'],
        startDate: DateTime.parse(j['start_date']),
        endDate: j['end_date'] != null ? DateTime.parse(j['end_date']) : null,
        value: j['value'],
        signed: j['signed'] ?? false,
        createdAt: DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'client_id': clientId,
        'contract_type': contractType,
        'title': title,
        'content': content,
        'pdf_url': pdfUrl,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'value': value,
        'signed': signed,
      };

  String get contractTypeLabel {
    switch (contractType) {
      case 'service_agreement': return 'Service Agreement';
      case 'freelance_contract': return 'Freelance Contract';
      case 'nda': return 'NDA';
      case 'rental_agreement': return 'Rental Agreement';
      case 'partnership': return 'Partnership';
      default: return contractType;
    }
  }
}

// ── Recurring Invoice ────────────────────────────
class RecurringInvoiceModel {
  final String id;
  final String userId;
  final String clientId;
  final ClientModel? client;
  final List<InvoiceItem> items;
  final double amount;
  final String frequency;
  final DateTime nextDate;
  final String status;
  final DateTime createdAt;

  const RecurringInvoiceModel({
    required this.id,
    required this.userId,
    required this.clientId,
    this.client,
    required this.items,
    required this.amount,
    required this.frequency,
    required this.nextDate,
    required this.status,
    required this.createdAt,
  });

  factory RecurringInvoiceModel.fromJson(Map<String, dynamic> j) => RecurringInvoiceModel(
        id: j['id'],
        userId: j['user_id'],
        clientId: j['client_id'],
        client: j['clients'] != null ? ClientModel.fromJson(j['clients']) : null,
        items: j['items'] != null ? (j['items'] as List).map((i) => InvoiceItem.fromJson(i)).toList() : [],
        amount: (j['amount'] as num).toDouble(),
        frequency: j['frequency'],
        nextDate: DateTime.parse(j['next_date']),
        status: j['status'] ?? 'active',
        createdAt: DateTime.parse(j['created_at']),
      );
}

// ── Quote ─────────────────────────────────────────
class QuoteModel {
  final String id;
  final String userId;
  final String clientId;
  final ClientModel? client;
  final List<InvoiceItem> items;
  final double total;
  final String status;
  final DateTime? validUntil;
  final String? notes;
  final DateTime createdAt;

  const QuoteModel({
    required this.id,
    required this.userId,
    required this.clientId,
    this.client,
    required this.items,
    required this.total,
    required this.status,
    this.validUntil,
    this.notes,
    required this.createdAt,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> j) => QuoteModel(
        id: j['id'],
        userId: j['user_id'],
        clientId: j['client_id'],
        client: j['clients'] != null ? ClientModel.fromJson(j['clients']) : null,
        items: j['items'] != null ? (j['items'] as List).map((i) => InvoiceItem.fromJson(i)).toList() : [],
        total: (j['total'] as num).toDouble(),
        status: j['status'] ?? 'draft',
        validUntil: j['valid_until'] != null ? DateTime.parse(j['valid_until']) : null,
        notes: j['notes'],
        createdAt: DateTime.parse(j['created_at']),
      );

  String get quoteNumber => 'QT-${id.substring(0, 6).toUpperCase()}';
}

// ── Product/Service ──────────────────────────────
class ProductModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final double? price;
  final String? unit;
  final String? category;
  final bool isActive;
  final DateTime createdAt;

  const ProductModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.price,
    this.unit,
    this.category,
    this.isActive = true,
    required this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> j) => ProductModel(
        id: j['id'],
        userId: j['user_id'],
        name: j['name'],
        description: j['description'],
        price: j['price'] != null ? (j['price'] as num).toDouble() : null,
        unit: j['unit'],
        category: j['category'],
        isActive: j['is_active'] ?? true,
        createdAt: DateTime.parse(j['created_at']),
      );
}

// ── Expense Budget ────────────────────────────────
class ExpenseBudgetModel {
  final String id;
  final String userId;
  final String category;
  final double amount;
  final DateTime month;
  final DateTime createdAt;

  const ExpenseBudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.month,
    required this.createdAt,
  });

  factory ExpenseBudgetModel.fromJson(Map<String, dynamic> j) => ExpenseBudgetModel(
        id: j['id'],
        userId: j['user_id'],
        category: j['category'],
        amount: (j['amount'] as num).toDouble(),
        month: DateTime.parse(j['month']),
        createdAt: DateTime.parse(j['created_at']),
      );
}
