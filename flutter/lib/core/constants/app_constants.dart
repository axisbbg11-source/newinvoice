class AppConstants {
  // Supabase — REPLACE WITH YOUR VALUES from Supabase Dashboard → Settings → API
  static const supabaseUrl = 'https://wgqsvqqubablmqdyomtv.supabase.co';
  static const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndncXN2cXF1YmFibG1xZHlvbXR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3MTk5NjYsImV4cCI6MjA5ODI5NTk2Nn0.2tQgCtqnB91eacqyoCKrDzRCsTCHE_NPT2jptF02lWI';

  // NOTE: testUserId removed for security - use authenticated user only
  // Storage bucket name
  static const supabaseStorageBucket = 'bizdesk-files';

  // Backend API — use localhost for dev builds so the browser can resolve it.
  // Change this to your deployed backend URL for production via --dart-define.
  static const defaultApiBaseUrl = 'http://127.0.0.1:8000';
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return defaultApiBaseUrl;
  }

  // App info
  static const appName = 'BizDesk';
  static const appVersion = '1.0.0';

  // Invoice status
  static const statusPaid = 'paid';
  static const statusPending = 'pending';
  static const statusOverdue = 'overdue';

  // Expense categories
  static const expenseCategories = [
    'Rent',
    'Supplies',
    'Travel',
    'Food',
    'Utilities',
    'Marketing',
    'Salary',
    'Equipment',
    'Maintenance',
    'Other',
  ];

  // Contract types
  static const contractTypes = [
    {'id': 'service_agreement', 'label': 'Service Agreement', 'desc': 'Standard service contract'},
    {'id': 'freelance_contract', 'label': 'Freelance Contract', 'desc': 'Independent contractor agreement'},
    {'id': 'nda', 'label': 'NDA', 'desc': 'Non-disclosure agreement'},
    {'id': 'rental_agreement', 'label': 'Rental Agreement', 'desc': 'Equipment or space rental'},
    {'id': 'partnership', 'label': 'Partnership', 'desc': 'Business partnership terms'},
  ];
}
