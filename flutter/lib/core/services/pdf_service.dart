import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';

class PdfService {
  static final _currencyFmt = NumberFormat('#,##,###', 'en_IN');
  static final _dateFmt = DateFormat('d MMM yyyy');

  /// Generate invoice PDF bytes
  static Future<pw.Document> generateInvoicePdf({
    required InvoiceModel invoice,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
  }) async {
    final pdf = pw.Document();
    final client = invoice.client;
    final isPaid = invoice.status == 'paid';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessName ?? 'Your Business',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1A73E8'),
                        ),
                      ),
                      if (businessAddress != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                      if (businessPhone != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                      if (businessEmail != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(businessEmail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(invoice.invoiceNumber, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Status badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: isPaid ? PdfColor.fromHex('#E6F4EA') : PdfColor.fromHex('#FFF8E1'),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  isPaid ? 'PAID' : (invoice.isOverdue ? 'OVERDUE' : 'PENDING'),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: isPaid ? PdfColor.fromHex('#1E8E3E') : PdfColor.fromHex('#F9A825'),
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Bill To & Dates
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          client?.name ?? 'Client',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        if (client?.email != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(client!.email!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                        if (client?.phone != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(client!.phone!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                        if (client?.address != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(client!.address!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Invoice Date: ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                          pw.Text(_dateFmt.format(invoice.invoiceDate), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Due Date: ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                          pw.Text(_dateFmt.format(invoice.dueDate), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      if (invoice.isOverdue && !isPaid) ...[
                        pw.SizedBox(height: 8),
                        pw.Text(
                          '${invoice.daysOverdue} days overdue',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#D93025'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  ...invoice.items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.name),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('₹${_currencyFmt.format(item.price)}', textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('₹${_currencyFmt.format(item.total)}', textAlign: pw.TextAlign.right),
                      ),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Total
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1A73E8'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      pw.Text(
                        '₹${_currencyFmt.format(invoice.total)}',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Notes
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                pw.Text('Notes', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.SizedBox(height: 8),
                pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.SizedBox(height: 20),
              ],

              // Payment terms
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Payment Terms', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('• Payment is due within the specified due date', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text('• Please include invoice number with your payment', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text('• For any queries, contact us', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Print invoice
  static Future<void> printInvoice(InvoiceModel invoice, {String? businessName, String? businessAddress}) async {
    final pdf = await generateInvoicePdf(
      invoice: invoice,
      businessName: businessName,
      businessAddress: businessAddress,
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Share invoice as PDF
  static Future<void> shareInvoice(
    InvoiceModel invoice, {
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
  }) async {
    final pdf = await generateInvoicePdf(
      invoice: invoice,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${invoice.invoiceNumber}.pdf',
    );
  }

  /// Get PDF bytes for saving
  static Future<List<int>> getPdfBytes(
    InvoiceModel invoice, {
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
  }) async {
    final pdf = await generateInvoicePdf(
      invoice: invoice,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
    );
    return pdf.save();
  }
}