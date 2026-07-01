from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from pydantic import BaseModel, EmailStr, validator
from typing import Optional, List
import os, httpx, json
from supabase import create_client, Client
from datetime import datetime, date
import weasyprint
from jinja2 import Template
import resend
from functools import wraps

# Rate limiter
limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="BizDesk API", version="1.0.0")
app.state.limiter = limiter

def rate_limit(max_per_minute: int = 60):
    """Rate limiting decorator"""
    def decorator(func):
        @wraps(func)
        async def wrapper(request: Request, *args, **kwargs):
            return await func(*args, **kwargs)
        return wrapper
    return decorator

# Handle rate limit errors
@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return {"error": "Rate limit exceeded", "detail": "Please try again later"}

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# ── Supabase client ──────────────────────────────
def get_supabase() -> Client:
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"])

# ── Audit Logging ─────────────────────────────────
def log_audit(supabase: Client, user_id: str, action: str, table_name: str, record_id: str = None, details: dict = None):
    """Log sensitive actions for security auditing"""
    try:
        supabase.table("audit_logs").insert({
            "user_id": user_id,
            "action": action,
            "table_name": table_name,
            "record_id": record_id,
            "details": details or {},
            "ip_address": os.environ.get("REMOTE_ADDR", "unknown")
        })
    except Exception:
        pass  # Don't fail if audit logging fails

# ── Groq AI helper ─────────────────────────────
async def groq_complete(prompt: str, system: str = "") -> str:
    async with httpx.AsyncClient() as client:
        res = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {os.environ['GROQ_API_KEY']}"},
            json={
                "model": "llama-3.3-70b-versatile",
                "max_tokens": 800,
                "messages": [
                    {"role": "system", "content": system or "You are a professional business assistant."},
                    {"role": "user", "content": prompt}
                ]
            },
            timeout=30
        )
        data = res.json()
        return data["choices"][0]["message"]["content"]

# ── PDF Generator ──────────────────────────────
INVOICE_HTML = """
<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: 'Inter', Arial, sans-serif; padding: 40px; color: #1f1f1f; }
  .header { display: flex; justify-content: space-between; margin-bottom: 40px; }
  .brand { font-size: 24px; font-weight: 600; color: #1A73E8; }
  .invoice-num { font-size: 13px; color: #5F6368; }
  .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 32px; }
  .label { font-size: 11px; color: #9AA0A6; text-transform: uppercase; letter-spacing: 0.05em; }
  .value { font-size: 14px; color: #1f1f1f; font-weight: 500; margin-top: 4px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
  th { font-size: 11px; color: #9AA0A6; text-transform: uppercase; text-align: left; padding: 8px 12px; border-bottom: 1px solid #E8EAED; }
  td { padding: 12px; border-bottom: 1px solid #E8EAED; font-size: 13px; }
  .total-row { font-weight: 600; font-size: 15px; }
  .status { display: inline-block; padding: 4px 12px; border-radius: 999px; font-size: 12px; font-weight: 500; }
  .pending { background: #FFF8E1; color: #F9A825; }
  .paid { background: #E6F4EA; color: #1E8E3E; }
  .overdue { background: #FCE8E6; color: #D93025; }
  .footer { margin-top: 40px; font-size: 12px; color: #9AA0A6; text-align: center; }
</style>
</head>
<body>
  <div class="header">
    <div>
      <div class="brand">{{ business_name }}</div>
      <div class="invoice-num">Invoice #{{ invoice_number }}</div>
    </div>
    <span class="status {{ status }}">{{ status | title }}</span>
  </div>
  <div class="info-grid">
    <div>
      <div class="label">Bill to</div>
      <div class="value">{{ client_name }}</div>
      {% if client_email %}<div style="font-size:12px;color:#5F6368">{{ client_email }}</div>{% endif %}
    </div>
    <div>
      <div class="label">Invoice date</div>
      <div class="value">{{ invoice_date }}</div>
      <div class="label" style="margin-top:12px">Due date</div>
      <div class="value">{{ due_date }}</div>
    </div>
  </div>
  <table>
    <thead><tr><th>Item</th><th>Qty</th><th>Price</th><th style="text-align:right">Total</th></tr></thead>
    <tbody>
      {% for item in items %}
      <tr>
        <td>{{ item.name }}</td>
        <td>{{ item.quantity }}</td>
        <td>₹{{ "%.2f"|format(item.price) }}</td>
        <td style="text-align:right">₹{{ "%.2f"|format(item.quantity * item.price) }}</td>
      </tr>
      {% endfor %}
    </tbody>
    <tfoot>
      <tr class="total-row"><td colspan="3" style="text-align:right;padding:16px 12px">Total</td><td style="text-align:right;padding:16px 12px">₹{{ "%.2f"|format(total) }}</td></tr>
    </tfoot>
  </table>
  {% if notes %}<div style="background:#F8F9FA;padding:16px;border-radius:8px;font-size:13px;color:#5F6368">{{ notes }}</div>{% endif %}
  <div class="footer">Generated by BizDesk · bizdesk.app</div>
</body>
</html>
"""

# ── Models with Input Validation ─────────────────────────────
class InvoiceItem(BaseModel):
    name: str
    quantity: int
    price: float

    @validator('quantity')
    def validate_quantity(cls, v):
        if v < 1:
            raise ValueError('Quantity must be at least 1')
        if v > 10000:
            raise ValueError('Quantity too large')
        return v

    @validator('price')
    def validate_price(cls, v):
        if v < 0:
            raise ValueError('Price cannot be negative')
        if v > 100000000:
            raise ValueError('Price too large')
        return v

class GeneratePDFRequest(BaseModel):
    invoice_id: str
    business_name: str
    client_name: str
    client_email: Optional[EmailStr] = None
    invoice_number: str
    invoice_date: str
    due_date: str
    status: str
    items: List[InvoiceItem]
    total: float
    notes: Optional[str]

    @validator('invoice_id')
    def validate_uuid(cls, v):
        if len(v) < 10 or len(v) > 100:
            raise ValueError('Invalid invoice ID')
        return v

    @validator('total')
    def validate_total(cls, v):
        if v < 0:
            raise ValueError('Total cannot be negative')
        if v > 100000000:
            raise ValueError('Total too large')
        return v

class GenerateReportRequest(BaseModel):
    user_id: str
    client_id: str
    client_name: str
    business_name: str
    period_start: str
    period_end: str
    work_logs: List[str]

class FollowupRequest(BaseModel):
    invoice_id: str
    client_email: str
    client_name: str
    business_name: str
    amount: float
    due_date: str
    days_overdue: int

class SendEmailRequest(BaseModel):
    to_email: str
    to_name: str
    subject: str
    body: str
    from_email: Optional[str] = None
    from_name: Optional[str] = None

class SendReportRequest(BaseModel):
    client_email: str
    client_name: str
    content: str
    business_name: str

# ── Invoice Auto-Email Models ───────────────────
class InvoiceEmailRequest(BaseModel):
    invoice_id: str
    client_email: str
    client_name: str
    client_phone: Optional[str] = None
    business_name: str
    invoice_number: str
    amount: float
    due_date: str
    invoice_date: str
    status: str
    notes: Optional[str] = None

class PaymentReceivedRequest(BaseModel):
    client_email: str
    client_name: str
    business_name: str
    invoice_number: str
    amount: float

# ── Routes ─────────────────────────────────────

@app.get("/")
def root():
    return {"status": "BizDesk backend running", "version": "1.0.0"}

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

# Generate invoice PDF (rate limited: 10 requests/minute)
@app.post("/api/v1/invoices/generate-pdf")
@limiter.limit("10/minute")
async def generate_invoice_pdf(request: Request, req: GeneratePDFRequest):
    try:
        template = Template(INVOICE_HTML)
        html = template.render(**req.dict())
        pdf_bytes = weasyprint.HTML(string=html).write_pdf()

        # Upload to Supabase Storage
        supabase = get_supabase()
        path = f"invoices/{req.invoice_id}.pdf"
        supabase.storage.from_("bizdesk-files").upload(path, pdf_bytes, {"content-type": "application/pdf", "upsert": "true"})
        url = supabase.storage.from_("bizdesk-files").get_public_url(path)

        # Update invoice with PDF url
        supabase.table("invoices").update({"pdf_url": url}).eq("id", req.invoice_id).execute()

        return {"pdf_url": url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Generate AI client report
@app.post("/api/v1/reports/generate")
async def generate_report(req: GenerateReportRequest):
    logs_text = "\n".join([f"- {log}" for log in req.work_logs])
    prompt = f"""
Generate a professional weekly client report for {req.client_name} from {req.business_name}.
Period: {req.period_start} to {req.period_end}

Work completed:
{logs_text}

Write a polished, professional 3-4 paragraph report. Be specific and positive. 
End with a brief note about what is planned next week.
Do NOT use markdown or bullet points. Write in flowing paragraphs.
"""
    content = await groq_complete(prompt, "You are a professional business writer. Write concise, professional client reports.")
    return {"content": content}

# AI follow-up email
@app.post("/api/v1/invoices/followup-email")
async def generate_followup_email(req: FollowupRequest):
    if req.days_overdue <= 3:
        tone = "gentle and friendly"
        subject_hint = "friendly reminder"
    elif req.days_overdue <= 7:
        tone = "polite but firm"
        subject_hint = "payment reminder"
    else:
        tone = "serious and professional, making clear this needs immediate attention"
        subject_hint = "final payment notice"

    prompt = f"""
Write a {tone} payment reminder email.
From: {req.business_name}
To: {req.client_name}
Invoice amount: ₹{req.amount}
Due date: {req.due_date}
Days overdue: {req.days_overdue}

Write just the email body (no subject line). Keep it under 100 words.
"""
    body = await groq_complete(prompt)
    subject = f"Payment Reminder — ₹{req.amount} ({subject_hint})"
    return {"subject": subject, "body": body}

# AI contract generator
@app.post("/api/v1/contracts/generate")
async def generate_contract(
    contract_type: str,
    party_a: str,
    party_b: str,
    details: str,
    duration: str,
    amount: Optional[str] = None
):
    prompt = f"""
Generate a professional {contract_type} between {party_a} (Service Provider) and {party_b} (Client).
Details: {details}
Duration: {duration}
{"Amount: " + amount if amount else ""}

Write a complete, professional legal contract with:
1. Parties involved
2. Scope of work/services
3. Payment terms
4. Duration and termination
5. Confidentiality
6. Dispute resolution
7. Signatures section

Keep it clear and simple — avoid excessive legal jargon.
"""
    content = await groq_complete(prompt, "You are a professional contract lawyer. Write clear, fair contracts.")
    return {"content": content}

# Send email (rate limited: 5 requests/minute to prevent abuse)
@app.post("/api/v1/emails/send")
@limiter.limit("5/minute")
async def send_email(request: Request, req: SendEmailRequest):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = req.from_email or os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        from_name = req.from_name or "BizDesk"

        r = resend.Emails.send({
            "from": f"{from_name} <{from_email}>",
            "to": req.to_email,
            "subject": req.subject,
            "html": f"<p>Dear {req.to_name},</p><p>{req.body}</p><p>Best regards,<br/>{req.business_name or 'BizDesk'}</p>"
        })
        return {"success": True, "message": "Email sent"}
    except Exception as e:
        return {"success": False, "error": str(e)}

# Send report to client
@app.post("/api/v1/reports/send")
async def send_report(req: SendReportRequest):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = req.business_name or "BizDesk"

        # Convert content to HTML (simple conversion)
        content_html = req.content.replace('\n', '<br/>')

        r = resend.Emails.send({
            "from": f"{business_name} <{from_email}>",
            "to": req.client_email,
            "subject": f"Report from {business_name}",
            "html": f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #1A73E8;">Work Report</h2>
                <p>Dear {req.client_name},</p>
                <div style="background: #F8F9FA; padding: 20px; border-radius: 8px; margin: 20px 0;">
                    {content_html}
                </div>
                <p style="color: #666; font-size: 12px;">Generated by BizDesk</p>
            </div>
            """
        })

        # Update report sent_at timestamp
        supabase = get_supabase()
        # You could update a reports table here if needed

        return {"success": True, "message": "Report sent successfully"}
    except Exception as e:
        return {"success": False, "error": str(e)}

# ── Auto-Send Invoice Email (Payment Reminder) ─────────────────────────────
@app.post("/api/v1/invoices/send-reminder")
async def send_invoice_reminder(req: InvoiceEmailRequest):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = req.business_name or "BizDesk"

        # Determine tone based on status
        if req.status == "overdue":
            tone = "serious but professional"
            subject = f"Urgent: Payment Overdue - Invoice #{req.invoice_number}"
        else:
            tone = "friendly reminder"
            subject = f"Payment Reminder - Invoice #{req.invoice_number}"

        # Generate email body using AI or template
        prompt = f"""
Write a {tone} payment reminder email for a business.
Business: {business_name}
Client: {req.client_name}
Invoice: #{req.invoice_number}
Amount: ₹{req.amount}
Due Date: {req.due_date}
Status: {req.status}

Keep it short (under 100 words), professional, and include the invoice details.
End with a polite request for payment.
"""
        try:
            body = await groq_complete(prompt, "You are a professional business writer.")
        except:
            # Fallback template if AI fails
            if req.status == "overdue":
                body = f"""Dear {req.client_name},

This is a friendly reminder that Invoice #{req.invoice_number} for ₹{req.amount} was due on {req.due_date}.

Kindly process the payment at your earliest convenience to avoid any late fees.

Thank you for your business!

Best regards,
{business_name}"""
            else:
                body = f"""Dear {req.client_name},

I hope this email finds you well!

This is a friendly reminder that Invoice #{req.invoice_number} for ₹{req.amount} is due on {req.due_date}.

Please let me know if you need any clarification.

Thank you!

Best regards,
{business_name}"""

        r = resend.Emails.send({
            "from": f"{business_name} <{from_email}>",
            "to": req.client_email,
            "subject": subject,
            "html": body.replace('\n', '<br/>')
        })

        return {"success": True, "message": "Payment reminder sent!"}
    except Exception as e:
        return {"success": False, "error": str(e)}

# ── Auto-Send Payment Received Thank You ────────────────────────────────────
@app.post("/api/v1/invoices/send-thankyou")
async def send_payment_thankyou(req: PaymentReceivedRequest):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = req.business_name or "BizDesk"

        prompt = f"""
Write a short, warm thank you email for receiving payment.
Business: {business_name}
Client: {req.client_name}
Invoice: #{req.invoice_number}
Amount: ₹{req.amount}

Keep it warm, short (under 80 words), and express gratitude.
"""
        try:
            body = await groq_complete(prompt, "You are a friendly business owner.")
        except:
            body = f"""Dear {req.client_name},

Thank you so much for your payment of ₹{req.amount} for Invoice #{req.invoice_number}!

We truly appreciate your business and prompt payment.

Looking forward to working with you again!

Best regards,
{business_name}"""

        r = resend.Emails.send({
            "from": f"{business_name} <{from_email}>",
            "to": req.client_email,
            "subject": f"Payment Received - Invoice #{req.invoice_number}",
            "html": body.replace('\n', '<br/>')
        })

        return {"success": True, "message": "Thank you email sent!"}
    except Exception as e:
        return {"success": False, "error": str(e)}

# ── Auto-Send Invoice Created Email ────────────────────────────────────────
@app.post("/api/v1/invoices/send-invoice")
async def send_invoice_created(req: InvoiceEmailRequest):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = req.business_name or "BizDesk"

        prompt = f"""
Write a professional invoice email to send to a client.
Business: {business_name}
Client: {req.client_name}
Invoice: #{req.invoice_number}
Amount: ₹{req.amount}
Due Date: {req.due_date}
Invoice Date: {req.invoice_date}

Include: invoice details, payment due date, payment methods (if mentioned in notes: {req.notes or 'none'}).
Keep it professional but friendly. Under 100 words.
"""
        try:
            body = await groq_complete(prompt, "You are a professional business owner.")
        except:
            body = f"""Dear {req.client_name},

Please find attached Invoice #{req.invoice_number} for ₹{req.amount}.

Due Date: {req.due_date}

{req.notes or 'Please process the payment at your earliest convenience.'}

Thank you for your business!

Best regards,
{business_name}"""

        r = resend.Emails.send({
            "from": f"{business_name} <{from_email}>",
            "to": req.client_email,
            "subject": f"Invoice #{req.invoice_number} from {business_name}",
            "html": body.replace('\n', '<br/>')
        })

        return {"success": True, "message": "Invoice sent!"}
    except Exception as e:
        return {"success": False, "error": str(e)}

# ── WhatsApp Message Models ─────────────────────────────────────────────
class WhatsAppRequest(BaseModel):
    phone: str
    message: str

# ── WhatsApp Reminder (using Twilio or similar) ─────────────────────────
@app.post("/api/v1/whatsapp/send")
async def send_whatsapp(req: WhatsAppRequest):
    """
    Send WhatsApp message.
    Note: Requires Twilio or similar WhatsApp Business API setup.
    For demo, we'll return a mock response.
    """
    try:
        # Check if TWILIO_WHATSAPP_SID is configured
        twilio_sid = os.environ.get("TWILIO_WHATSAPP_SID", "")
        twilio_token = os.environ.get("TWILIO_WHATSAPP_TOKEN", "")

        if twilio_sid and twilio_token:
            from twilio.rest import Client
            client = Client(twilio_sid, twilio_token)

            message = client.messages.create(
                from_=f'whatsapp:{os.environ.get("TWILIO_WHATSAPP_FROM")}',
                body=req.message,
                to=f'whatsapp:{req.phone}'
            )
            return {"success": True, "message_id": message.sid}
        else:
            # Return the message for manual sending (demo mode)
            return {
                "success": True,
                "demo": True,
                "message": "WhatsApp not configured. Use the message below:",
                "whatsapp_message": req.message,
                "phone": req.phone
            }
    except Exception as e:
        return {"success": False, "error": str(e)}

# ── Auto-Send Invoice via WhatsApp ───────────────────────────────────────
@app.post("/api/v1/invoices/send-whatsapp")
async def send_invoice_whatsapp(req: InvoiceEmailRequest):
    phone = req.client_phone or ""
    if not phone:
        return {"success": False, "error": "No phone number"}

    # Clean phone number
    phone = ''.join(c for c in phone if c.isdigit())
    if not phone.startswith('91'):
        phone = '91' + phone

    message = f"""
Hi {req.client_name},

Please find your invoice #{req.invoice_number} from {req.business_name}.

Amount: ₹{req.amount}
Due Date: {req.due_date}

{req.notes or 'Please process the payment at your earliest convenience.'}

Thank you!
"""
    return await send_whatsapp(WhatsAppRequest(phone=f"+{phone}", message=message))

# ── AI Chat Endpoint (keep API key server-side) ───────────────────────────
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    message: str
    context: Optional[str] = None

@app.post("/api/v1/ai/chat")
@limiter.limit("10/minute")
async def chat(request: Request, req: ChatRequest):
    """AI chat endpoint - API key stays on server"""
    try:
        system_prompt = """You are BizDesk AI assistant for a small business owner.
Be friendly, concise, and helpful. Answer in 2-4 short sentences max.
Use simple language — the user may be a shopkeeper or small business owner, not a tech expert.
Always respond in the same language the user writes in."""

        if req.context:
            system_prompt += f"\n\nHere is their live business data:\n{req.context}"

        response = await groq_complete(req.message, system_prompt)
        return {"response": response}
    except Exception as e:
        return {"error": str(e)}

# Dashboard summary
@app.get("/api/v1/dashboard/{user_id}")
def get_dashboard(user_id: str):
    supabase = get_supabase()
    from_date = date.today().replace(day=1).isoformat()

    invoices = supabase.table("invoices").select("*").eq("user_id", user_id).gte("created_at", from_date).execute().data
    expenses = supabase.table("expenses").select("*").eq("user_id", user_id).gte("date", from_date).execute().data

    income = sum(i["total"] for i in invoices if i["status"] == "paid")
    total_expenses = sum(e["amount"] for e in expenses)
    owed = sum(i["total"] for i in invoices if i["status"] in ["pending", "overdue"])
    overdue = [i for i in invoices if i["status"] == "overdue"]
    pending = [i for i in invoices if i["status"] == "pending"]

    return {
        "total_income": income,
        "total_expenses": total_expenses,
        "profit": income - total_expenses,
        "total_owed": owed,
        "overdue_count": len(overdue),
        "pending_count": len(pending),
    }
