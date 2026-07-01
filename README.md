# BizDesk

> Run your business from your pocket.

Invoice chasing, client reports, expense tracking, AI assistant — all in one mobile app for any business.

---

## Stack

| Layer | Tech |
|---|---|
| Mobile | Flutter (Android + iOS) |
| Backend | FastAPI → Railway |
| Database | Supabase (PostgreSQL) |
| AI | Groq API — Llama 3.3 70B (FREE) |
| Automation | n8n |
| Email | Resend.com (free 3000/mo) |
| PDF | WeasyPrint |

---

## Setup — Step by Step

### 1. Supabase
1. Go to supabase.com → New project
2. SQL Editor → paste the SQL from docs (tables + RLS policies) → Run
3. **Storage bucket:**
   - Go to Storage → New bucket
   - Name: `bizdesk-files`
   - Toggle "Public" ON
   - Click Create
4. Copy: Project URL + anon key + service role key

### 2. Groq (Free AI)
1. Go to console.groq.com → Sign up free
2. API Keys → Create key
3. Copy the key

### 3. Resend (Free email)
1. Go to resend.com → Sign up free
2. API Keys → Create key
3. Add your domain or use their sandbox

### 4. Flutter App
```bash
cd flutter
# Open lib/core/constants/app_constants.dart
# Fill in:
# - supabaseUrl
# - supabaseAnonKey
# - apiBaseUrl (your Railway URL after deploy)
# - groqApiKey

flutter pub get
flutter run
```

### 5. Backend (Railway)
```bash
cd backend

# Create .env file:
SUPABASE_URL=your_url
SUPABASE_SERVICE_KEY=your_service_key
GROQ_API_KEY=your_groq_key
RESEND_API_KEY=your_resend_key

# Deploy to Railway:
# 1. Push to GitHub
# 2. railway.app → New project → Deploy from GitHub
# 3. Add environment variables
# 4. Add start command: uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

### 6. n8n Automation
1. Go to n8n.io → Start free cloud or self-host
2. Import `backend/n8n_invoice_followup_workflow.json`
3. Set environment variables: SUPABASE_URL, SUPABASE_SERVICE_KEY, BACKEND_URL, RESEND_API_KEY
4. Activate workflow

---

## Features

### ✅ Built
- [x] Auth (login, signup, onboarding)
- [x] Home dashboard (money in, out, who owes you)
- [x] Create invoices + WhatsApp share
- [x] AI assistant powered by Groq (free)
- [x] Auto follow-up emails via n8n
- [x] Supabase schema with RLS

### 🔨 In progress (Week 2-3)
- [ ] Clients management screen
- [ ] Invoices list + detail screen
- [ ] Expense tracker with photo
- [ ] PDF invoice generation
- [ ] Reports screen + AI generator
- [ ] Contract builder
- [ ] Mock payment screen

---

## Monetization (add Razorpay later)

| Plan | Price | Features |
|---|---|---|
| Free | ₹0 | 3 clients, 5 invoices/mo |
| Pro | ₹499/mo | Unlimited, AI follow-ups, reports |
| Agency | ₹1499/mo | Team, white-label PDF |

---

## Folder Structure

```
bizdesk/
├── flutter/
│   └── lib/
│       ├── core/          # theme, constants, router
│       ├── data/          # models, repositories
│       └── features/
│           ├── auth/      # login, signup, onboarding, splash
│           ├── home/      # dashboard
│           ├── invoices/  # create, list, detail
│           ├── clients/   # list, add, detail
│           ├── expenses/  # list, add
│           ├── reports/   # list, generate
│           └── ai_assistant/ # chat screen
└── backend/
    ├── app/main.py        # FastAPI routes
    ├── migrations/        # Supabase SQL
    ├── requirements.txt
    └── n8n_*.json         # Import into n8n
```
