from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from pydantic import BaseModel, EmailStr, validator, field_validator
from typing import Optional, List
import os, re, json, logging, httpx
from supabase import create_client, Client
from datetime import datetime, date, timedelta
import random
from jinja2 import Template
import resend
from functools import wraps
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Security: HTML sanitization for XSS prevention
def sanitize_html(text: str) -> str:
    """Sanitize user input to prevent XSS in HTML context"""
    if not text:
        return text
    # Escape HTML entities
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    text = text.replace('"', '&quot;')
    text = text.replace("'", '&#x27;')
    return text

def sanitize_for_prompt(text: str) -> str:
    """Sanitize input for AI prompts to prevent prompt injection"""
    if not text:
        return text
    # Remove control characters
    text = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', text)
    # Remove potential injection patterns
    text = re.sub(r'(?i)(system|assistant|human):', '', text)
    return text.strip()

def validate_phone(phone: str) -> str:
    """Validate and clean phone number"""
    if not phone:
        return ""
    # Allow E.164 or local numbers; strip spaces/characters but keep leading + if present
    cleaned = ''.join(c for c in phone if c.isdigit())
    if phone.strip().startswith('+'):
        cleaned = '+' + cleaned
    # normalize to E.164-like numeric string (without +) for internal use
    digits = cleaned.lstrip('+')
    if len(digits) < 10 or len(digits) > 15:
        raise ValueError("Invalid phone number")
    return '+' + digits


def import_weasyprint():
    try:
        import weasyprint
        return weasyprint
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=(
                "WeasyPrint native dependencies are missing. "
                "Deploy using Docker or install GTK/Cairo/Pango native libs. "
                f"Original error: {e}"
            ),
        )

# ── Authentication ───────────────────────────────────────────────────
security = HTTPBearer(auto_error=False)

async def get_current_user(request: Request, credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Verify Supabase JWT token and return user info"""
    if not credentials:
        raise HTTPException(status_code=401, detail="Not authenticated", headers={"WWW-Authenticate": "Bearer"})

    try:
        supabase = get_supabase()
        # Verify the token with Supabase
        user_response = supabase.auth.get_user(credentials.credentials)
        if not user_response or not user_response.user:
            raise HTTPException(status_code=401, detail="Invalid token")

        # Get user from users table
        user_data = supabase.table("users").select("*").eq("id", user_response.user.id).execute()
        if not user_data.data:
            raise HTTPException(status_code=401, detail="User not found")

        return user_data.data[0]
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Auth error: {str(e)}")
        raise HTTPException(status_code=401, detail="Authentication failed")

async def get_optional_user(request: Request, credentials: HTTPAuthorizationCredentials = Depends(security)) -> Optional[dict]:
    """Optional auth - returns user if valid token, None otherwise"""
    if not credentials:
        return None
    try:
        return await get_current_user(request, credentials)
    except Exception:
        return None

# Rate limiter - use IP only for better stability
def get_rate_limit_key(request: Request) -> str:
    """Use IP address for rate limiting"""
    return get_remote_address(request)

limiter = Limiter(key_func=get_rate_limit_key)
app = FastAPI(title="BizDesk API", version="1.0.0")
app.state.limiter = limiter

def rate_limit(max_per_minute: int = 60):
    """Rate limiting decorator - now actually functional"""
    def decorator(func):
        return limiter.limit(f"{max_per_minute}/minute")(func)
    return decorator

# Handle rate limit errors
@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    raise HTTPException(status_code=429, detail="Rate limit exceeded. Please try again later.")

# CORS - FIXED: Specify explicit origins instead of wildcard
# In production, replace with your actual frontend domains
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000,https://bizdesk.app").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
)

# ── Supabase client ──────────────────────────────
def get_supabase() -> Client:
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_SERVICE_KEY")

    if not supabase_url:
        raise HTTPException(status_code=500, detail="SUPABASE_URL not configured")
    if not supabase_key:
        raise HTTPException(status_code=500, detail="SUPABASE_SERVICE_KEY not configured")

    return create_client(supabase_url, supabase_key)


def validate_config() -> None:
    required = [
        "SUPABASE_URL",
        "SUPABASE_SERVICE_KEY",
        "GROQ_API_KEY",
        "RESEND_API_KEY",
        "FROM_EMAIL",
        "FROM_NAME",
        "TWILIO_ACCOUNT_SID",
        "TWILIO_AUTH_TOKEN",
        "TWILIO_MESSAGING_SID",
    ]
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")


@app.on_event("startup")
def startup_event() -> None:
    try:
        validate_config()
        logger.info("Configuration validated successfully.")
    except Exception as exc:
        logger.critical(f"Startup configuration error: {exc}")
        raise


def verify_invoice_ownership(invoice_id: str, current_user: dict):
    """Verify that the current user owns the invoice."""
    supabase = get_supabase()
    invoice = supabase.table("invoices").select("user_id").eq("id", invoice_id).execute()
    if not invoice.data:
        raise HTTPException(status_code=404, detail="Invoice not found")
    if invoice.data[0]["user_id"] != current_user.get("id"):
        raise HTTPException(status_code=403, detail="Not authorized to access this invoice")
    return True

# ── Audit Logging ─────────────────────────────────
def log_audit(request: Request, supabase: Client, user_id: str, action: str, table_name: str, record_id: str = None, details: dict = None):
    """Log sensitive actions for security auditing"""
    try:
        # Get real IP from request
        ip_address = request.headers.get("X-Forwarded-For", request.client.host if request.client else "unknown")
        supabase.table("audit_logs").insert({
            "user_id": user_id,
            "action": action,
            "table_name": table_name,
            "record_id": record_id,
            "details": details or {},
            "ip_address": ip_address
        })
    except Exception:
        pass  # Don't fail if audit logging fails

# ── Groq AI helper ─────────────────────────────
async def groq_complete(prompt: str, system: str = "") -> str:
    groq_key = os.environ.get("GROQ_API_KEY")
    if not groq_key:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY not configured")

    async with httpx.AsyncClient() as client:
        res = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {groq_key}"},
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
        if res.status_code != 200:
            logger.error(f"Groq API error: {res.text}")
            raise HTTPException(status_code=503, detail="AI service temporarily unavailable")

        data = res.json()
        if not data.get("choices") or not data["choices"]:
            raise HTTPException(status_code=503, detail="Invalid AI response")

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

    @field_validator('quantity')
    @classmethod
    def validate_quantity(cls, v):
        if v < 1:
            raise ValueError('Quantity must be at least 1')
        if v > 10000:
            raise ValueError('Quantity too large')
        return v

    @field_validator('price')
    @classmethod
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

    @field_validator('invoice_id')
    @classmethod
    def validate_uuid(cls, v):
        if len(v) < 10 or len(v) > 100:
            raise ValueError('Invalid invoice ID')
        return v

    @field_validator('total')
    @classmethod
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

# Generate invoice PDF (rate limited: 10 requests/minute) - PROTECTED
@app.post("/api/v1/invoices/generate-pdf")
@limiter.limit("10/minute")
async def generate_invoice_pdf(request: Request, req: GeneratePDFRequest, current_user: dict = Depends(get_current_user)):
    try:
        supabase = get_supabase()

        # FIRST: Verify ownership before ANY operation (IDOR fix)
        invoice = supabase.table("invoices").select("user_id").eq("id", req.invoice_id).execute()
        if not invoice.data:
            raise HTTPException(status_code=404, detail="Invoice not found")

        # Verify user owns this invoice
        if invoice.data[0]["user_id"] != current_user.get("id"):
            raise HTTPException(status_code=403, detail="Not authorized to access this invoice")

        # Generate PDF
        template = Template(INVOICE_HTML)
        html = template.render(**req.dict())
        weasyprint = import_weasyprint()
        pdf_bytes = weasyprint.HTML(string=html).write_pdf()

        # Upload to Supabase Storage
        path = f"invoices/{req.invoice_id}.pdf"
        supabase.storage.from_("bizdesk-files").upload(path, pdf_bytes, {"content-type": "application/pdf", "upsert": "true"})
        url = supabase.storage.from_("bizdesk-files").get_public_url(path)

        # Update invoice with PDF url
        supabase.table("invoices").update({"pdf_url": url}).eq("id", req.invoice_id).execute()

        return {"pdf_url": url}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"PDF generation error: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to generate PDF")

# Generate AI client report
@app.post("/api/v1/reports/generate")
async def generate_report(req: GenerateReportRequest, current_user: dict = Depends(get_current_user)):
    # Sanitize user inputs to prevent prompt injection
    safe_client_name = sanitize_for_prompt(req.client_name)
    safe_business_name = sanitize_for_prompt(req.business_name)
    safe_logs = [sanitize_for_prompt(log) for log in req.work_logs]

    logs_text = "\n".join([f"- {log}" for log in safe_logs])
    prompt = f"""
Generate a professional weekly client report for {safe_client_name} from {safe_business_name}.
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
async def generate_followup_email(req: FollowupRequest, current_user: dict = Depends(get_current_user)):
    # Sanitize inputs
    safe_business_name = sanitize_for_prompt(req.business_name)
    safe_client_name = sanitize_for_prompt(req.client_name)

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
From: {safe_business_name}
To: {safe_client_name}
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
    amount: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    # Sanitize inputs
    safe_contract_type = sanitize_for_prompt(contract_type)
    safe_party_a = sanitize_for_prompt(party_a)
    safe_party_b = sanitize_for_prompt(party_b)
    safe_details = sanitize_for_prompt(details)

    prompt = f"""
Generate a professional {safe_contract_type} between {safe_party_a} (Service Provider) and {safe_party_b} (Client).
Details: {safe_details}
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
async def send_email(request: Request, req: SendEmailRequest, current_user: dict = Depends(get_current_user)):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        authoritative_from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        from_name = os.environ.get("FROM_NAME", "BizDesk")

        # Sanitize user input to prevent XSS
        safe_to_name = sanitize_html(req.to_name)
        safe_body = sanitize_html(req.body)
        safe_subject = sanitize_html(req.subject)

        r = resend.Emails.send({
            "from": f"{from_name} <{authoritative_from_email}>",
            "to": req.to_email,
            "subject": safe_subject,
            "html": f"<p>Dear {safe_to_name},</p><p>{safe_body}</p><p>Best regards,<br/>{sanitize_html(req.business_name or 'BizDesk')}</p>"
        })
        return {"success": True, "message": "Email sent"}
    except Exception as e:
        logger.error(f"Email send error: {str(e)}")
        return {"success": False, "error": "Failed to send email"}

# Send report to client
@app.post("/api/v1/reports/send")
async def send_report(req: SendReportRequest, current_user: dict = Depends(get_current_user)):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = sanitize_html(req.business_name or "BizDesk")

        # Sanitize content to prevent XSS - convert newlines but escape HTML
        safe_content = sanitize_html(req.content).replace('\n', '<br/>')
        safe_client_name = sanitize_html(req.client_name)

        r = resend.Emails.send({
            "from": f"{business_name} <{from_email}>",
            "to": req.client_email,
            "subject": f"Report from {business_name}",
            "html": f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #1A73E8;">Work Report</h2>
                <p>Dear {safe_client_name},</p>
                <div style="background: #F8F9FA; padding: 20px; border-radius: 8px; margin: 20px 0;">
                    {safe_content}
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
        logger.error(f"Report send error: {str(e)}")
        return {"success": False, "error": "Failed to send report"}

# ── Auto-Send Invoice Email (Payment Reminder) ─────────────────────────────
@app.post("/api/v1/invoices/send-reminder")
async def send_invoice_reminder(req: InvoiceEmailRequest, current_user: dict = Depends(get_current_user)):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = sanitize_html(req.business_name or "BizDesk")
        client_name = sanitize_html(req.client_name)

        # Determine tone based on status
        if req.status == "overdue":
            tone = "serious but professional"
            subject = f"Urgent: Payment Overdue - Invoice #{req.invoice_number}"
        else:
            tone = "friendly reminder"
            subject = f"Payment Reminder - Invoice #{req.invoice_number}"

        # Sanitize inputs for AI prompt
        safe_business = sanitize_for_prompt(req.business_name or "BizDesk")
        safe_client = sanitize_for_prompt(req.client_name)

        # Generate email body using AI or template
        prompt = f"""
Write a {tone} payment reminder email for a business.
Business: {safe_business}
Client: {safe_client}
Invoice: #{req.invoice_number}
Amount: ₹{req.amount}
Due Date: {req.due_date}
Status: {req.status}

Keep it short (under 100 words), professional, and include the invoice details.
End with a polite request for payment.
"""
        try:
            body = await groq_complete(prompt, "You are a professional business writer.")
        except Exception:
            # Fallback template if AI fails
            if req.status == "overdue":
                body = f"""Dear {client_name},

This is a friendly reminder that Invoice #{req.invoice_number} for ₹{req.amount} was due on {req.due_date}.

Kindly process the payment at your earliest convenience to avoid any late fees.

Thank you for your business!

Best regards,
{business_name}"""
            else:
                body = f"""Dear {client_name},

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
        logger.error(f"Reminder email error: {str(e)}")
        return {"success": False, "error": "Failed to send reminder"}

# ── Auto-Send Payment Received Thank You ────────────────────────────────────
@app.post("/api/v1/invoices/send-thankyou")
async def send_payment_thankyou(req: PaymentReceivedRequest, current_user: dict = Depends(get_current_user)):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = sanitize_html(req.business_name or "BizDesk")
        client_name = sanitize_html(req.client_name)

        # Sanitize for AI prompt
        safe_business = sanitize_for_prompt(req.business_name or "BizDesk")
        safe_client = sanitize_for_prompt(req.client_name)

        prompt = f"""
Write a short, warm thank you email for receiving payment.
Business: {safe_business}
Client: {safe_client}
Invoice: #{req.invoice_number}
Amount: ₹{req.amount}

Keep it warm, short (under 80 words), and express gratitude.
"""
        try:
            body = await groq_complete(prompt, "You are a friendly business owner.")
        except:
            body = f"""Dear {client_name},

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
        logger.error(f"Thankyou email error: {str(e)}")
        return {"success": False, "error": "Failed to send thank you email"}

# ── Auto-Send Invoice Created Email ────────────────────────────────────────
@app.post("/api/v1/invoices/send-invoice")
async def send_invoice_created(req: InvoiceEmailRequest, current_user: dict = Depends(get_current_user)):
    try:
        resend.api_key = os.environ.get("RESEND_API_KEY", "")
        if not resend.api_key:
            return {"success": False, "error": "RESEND_API_KEY not configured"}

        from_email = os.environ.get("FROM_EMAIL", "onboarding@resend.dev")
        business_name = sanitize_html(req.business_name or "BizDesk")
        client_name = sanitize_html(req.client_name)
        notes = sanitize_html(req.notes or 'Please process the payment at your earliest convenience.')

        # Sanitize for AI prompt
        safe_business = sanitize_for_prompt(req.business_name or "BizDesk")
        safe_client = sanitize_for_prompt(req.client_name)
        safe_notes = sanitize_for_prompt(req.notes or 'none')

        prompt = f"""
Write a professional invoice email to send to a client.
Business: {safe_business}
Client: {safe_client}
Invoice: #{req.invoice_number}
Amount: ₹{req.amount}
Due Date: {req.due_date}
Invoice Date: {req.invoice_date}

Include: invoice details, payment due date, payment methods (if mentioned in notes: {safe_notes}).
Keep it professional but friendly. Under 100 words.
"""
        try:
            body = await groq_complete(prompt, "You are a professional business owner.")
        except:
            body = f"""Dear {client_name},

Please find attached Invoice #{req.invoice_number} for ₹{req.amount}.

Due Date: {req.due_date}

{notes}

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
        logger.error(f"Invoice email error: {str(e)}")
        return {"success": False, "error": "Failed to send invoice"}

# ── WhatsApp Message Models ─────────────────────────────────────────────
class WhatsAppRequest(BaseModel):
    phone: str
    message: str

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v):
        if not v:
            raise ValueError("Phone number is required")
        # Remove non-digit characters for validation
        clean = ''.join(c for c in v if c.isdigit())
        if len(clean) < 10:
            raise ValueError("Invalid phone number")
        return v

    @field_validator('message')
    @classmethod
    def validate_message(cls, v):
        if not v:
            raise ValueError("Message is required")
        if len(v) > 4096:
            raise ValueError("Message too long (max 4096 characters)")
        return v


# ── Twilio SMS OTP (simple implementation) ───────────────────────────────
OTP_STORE: dict = {}

class SendOTPRequest(BaseModel):
    email: EmailStr
    phone: str

class VerifyOTPRequest(BaseModel):
    email: EmailStr
    phone: str
    code: str


def normalize_phone_digits(phone: str) -> str:
    return ''.join(c for c in phone if c.isdigit())


@app.post("/auth/send-otp")
@rate_limit(10)
async def send_otp(req: SendOTPRequest):
    """Send a 6-digit OTP to the provided phone using Twilio Messaging API.
    Note: This implementation stores OTPs in-memory (ephemeral)."""
    try:
        phone = validate_phone(req.phone)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    email = req.email.strip().lower()
    supabase = get_supabase()
    user_resp = supabase.table("users").select("id, email, phone").eq("email", email).maybe_single()
    if not user_resp or not user_resp.data:
        raise HTTPException(status_code=400, detail="No user found with that email")

    user_data = user_resp.data
    stored_phone = user_data.get("phone") or ""
    if normalize_phone_digits(stored_phone) != normalize_phone_digits(phone):
        raise HTTPException(status_code=400, detail="Phone number does not match the user account")

    code = f"{random.randint(100000, 999999)}"
    expires = datetime.utcnow() + timedelta(minutes=5)
    OTP_STORE[f"{email}|{phone}"] = {"code": code, "expires_at": expires}

    sid = os.environ.get("TWILIO_ACCOUNT_SID")
    token = os.environ.get("TWILIO_AUTH_TOKEN")
    messaging_sid = os.environ.get("TWILIO_MESSAGING_SID")
    demo_mode = os.environ.get("OTP_DEMO_MODE", "false").lower() in ("1", "true", "yes")

    if not (sid and token and messaging_sid):
        if not demo_mode:
            logger.error("Twilio OTP not configured and demo mode disabled")
            raise HTTPException(status_code=500, detail="OTP sending is not configured")
        logger.info(f"Demo OTP for {email} {phone}: {code}")
        return {"success": True, "demo": True}

    url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"
    data = {
        "To": phone,
        "MessagingServiceSid": messaging_sid,
        "Body": f"Your BizDesk verification code is {code}" 
    }

    async with httpx.AsyncClient() as client:
        resp = await client.post(url, data=data, auth=(sid, token), timeout=10)
        if resp.status_code not in (200, 201):
            logger.error(f"Twilio send failed: {resp.status_code} {resp.text}")
            raise HTTPException(status_code=502, detail="Failed to send SMS via Twilio")

    return {"success": True}


@app.post("/auth/verify-otp")
@rate_limit(10)
async def verify_otp(req: VerifyOTPRequest):
    try:
        phone = validate_phone(req.phone)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    email = req.email.strip().lower()
    key = f"{email}|{phone}"
    entry = OTP_STORE.get(key)
    if not entry:
        raise HTTPException(status_code=400, detail="No OTP requested for this email and phone")

    if entry["expires_at"] < datetime.utcnow():
        del OTP_STORE[key]
        raise HTTPException(status_code=400, detail="OTP expired")

    if entry["code"] != req.code:
        raise HTTPException(status_code=400, detail="Invalid OTP")

    del OTP_STORE[key]
    return {"success": True, "message": "Phone verified"}


# ── WhatsApp Reminder (using Twilio or similar) ─────────────────────────
@app.post("/api/v1/whatsapp/send")
async def send_whatsapp(req: WhatsAppRequest, current_user: dict = Depends(get_current_user)):
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
            # Return the message for manual sending (demo mode) - NOT actually sent
            return {
                "success": False,
                "demo": True,
                "error": "WhatsApp not configured (demo mode)",
                "message": "Configure TWILIO_WHATSAPP_SID and TWILIO_WHATSAPP_TOKEN to send",
                "whatsapp_message": req.message,
                "phone": req.phone
            }
    except Exception as e:
        logger.error(f"WhatsApp error: {str(e)}")
        return {"success": False, "error": "Failed to send WhatsApp message"}

# ── Auto-Send Invoice via WhatsApp ───────────────────────────────────────
@app.post("/api/v1/invoices/send-whatsapp")
async def send_invoice_whatsapp(req: InvoiceEmailRequest, current_user: dict = Depends(get_current_user)):
    if not req.client_phone:
        return {"success": False, "error": "No phone number"}

    # Validate phone number
    try:
        phone = validate_phone(req.client_phone)
    except ValueError as e:
        return {"success": False, "error": str(e)}

    # Sanitize inputs
    safe_client_name = sanitize_html(req.client_name)
    safe_business_name = sanitize_html(req.business_name)
    safe_notes = sanitize_html(req.notes or 'Please process the payment at your earliest convenience.')

    message = f"""
Hi {safe_client_name},

Please find your invoice #{req.invoice_number} from {safe_business_name}.

Amount: ₹{req.amount}
Due Date: {req.due_date}

{safe_notes}

Thank you!
"""
    return await send_whatsapp(WhatsAppRequest(phone=f"+{phone}", message=message), current_user)

# ── AI Chat Endpoint (keep API key server-side) ───────────────────────────
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    message: str
    context: Optional[str] = None

@app.post("/api/v1/ai/chat")
@limiter.limit("10/minute")
async def chat(request: Request, req: ChatRequest, current_user: dict = Depends(get_current_user)):
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

# Dashboard summary - PROTECTED
@app.get("/api/v1/dashboard/{user_id}")
def get_dashboard(user_id: str, current_user: dict = Depends(get_current_user)):
    # Only allow users to view their own dashboard
    if current_user.get("id") != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this dashboard")

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
