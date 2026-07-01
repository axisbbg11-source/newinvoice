class AppConstants {
  // Supabase — REPLACE WITH YOUR VALUES from Supabase Dashboard → Settings → API
  // In production, use environment variables
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://wgqsvqqubablmqdyomtv.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndncXN2cXF1YmFibG1xZHlvbXR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3MTk5NjYsImV4cCI6MjA5ODI5NTk2Nn0.2tQgCtqnB91eacqyoCKrDzRCsTCHE_NPT2jptF02lWI');

  // NOTE: testUserId removed for security - use authenticated user only
  // Storage bucket name
  static const supabaseStorageBucket = 'bizdesk-files';

  // Backend API — all API keys are kept server-side only
  // In production, use environment variables
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://newinvoice.railway.internal');

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
