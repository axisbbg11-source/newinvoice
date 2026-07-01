-- ════════════════════════════════════════════
-- BizDesk — Unique Features Schema
-- ════════════════════════════════════════════

-- ── Recurring Invoices ────────────────────────
CREATE TABLE IF NOT EXISTS recurring_invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  items JSONB NOT NULL DEFAULT '[]',
  amount NUMERIC(12,2) NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('weekly', 'monthly', 'quarterly', 'yearly')),
  next_date DATE NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE recurring_invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "recurring_own" ON recurring_invoices FOR ALL USING (auth.uid() = user_id);

-- ── Quotes/Estimates ────────────────────────────
CREATE TABLE IF NOT EXISTS quotes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  items JSONB NOT NULL DEFAULT '[]',
  total NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'accepted', 'rejected', 'converted')),
  valid_until DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "quotes_own" ON quotes FOR ALL USING (auth.uid() = user_id);

-- ── Product/Service Catalog ────────────────────
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(12,2),
  unit TEXT, -- per hour, per piece, etc.
  category TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "products_own" ON products FOR ALL USING (auth.uid() = user_id);

-- ── Expense Budgets ─────────────────────────────
CREATE TABLE IF NOT EXISTS expense_budgets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  month DATE NOT NULL, -- first day of month
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE expense_budgets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "budgets_own" ON expense_budgets FOR ALL USING (auth.uid() = user_id);

-- ── Client Portal Access ────────────────────────
ALTER TABLE clients ADD COLUMN IF NOT EXISTS portal_token UUID;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS portal_enabled BOOLEAN DEFAULT FALSE;