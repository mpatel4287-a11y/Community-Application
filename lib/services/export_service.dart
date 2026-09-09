// lib/services/export_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/member_model.dart';

class ExportService {
  /// Export all families and members data to an Excel (.xlsx) file
  static Future<void> exportToExcel({
    required String title,
    required List<Map<String, dynamic>> familiesData,
  }) async {
    try {
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Family Details'];
      excel.setDefaultSheet('Family Details');

      // Define header styles
      final CellStyle headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      );

      // Define Headers
      final List<String> headers = [
        'Family ID',
        'Family Name',
        'Member MID',
        'Full Name',
        'Surname',
        'Father Name',
        'Mother Name',
        'Gender',
        'Birth Date',
        'Blood Group',
        'Marriage Status',
        'Phone Number',
        'WhatsApp',
        'Email',
        'Native Home / Village',
        'Gotra',
        'Education',
        'Address',
        'Status',
      ];

      // Add Headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Add Data Rows
      for (final fam in familiesData) {
        final familyId = fam['familyId']?.toString() ?? '-';
        final familyName = fam['familyName']?.toString() ?? 'Family';
        final List<MemberModel> members = fam['members'] as List<MemberModel>? ?? [];

        if (members.isEmpty) {
          sheet.appendRow([
            TextCellValue(familyId),
            TextCellValue(familyName),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('Active'),
          ]);
        } else {
          for (final m in members) {
            sheet.appendRow([
              TextCellValue(familyId),
              TextCellValue(familyName),
              TextCellValue(m.mid.isNotEmpty ? m.mid : '-'),
              TextCellValue(m.fullName.isNotEmpty ? m.fullName : '-'),
              TextCellValue(m.surname.isNotEmpty ? m.surname : '-'),
              TextCellValue(m.fatherName.isNotEmpty ? m.fatherName : '-'),
              TextCellValue(m.motherName.isNotEmpty ? m.motherName : '-'),
              TextCellValue(m.gender.isNotEmpty ? m.gender : '-'),
              TextCellValue(m.birthDate.isNotEmpty ? m.birthDate : '-'),
              TextCellValue(m.bloodGroup.isNotEmpty ? m.bloodGroup : '-'),
              TextCellValue(m.marriageStatus.isNotEmpty ? m.marriageStatus : '-'),
              TextCellValue(m.phone.isNotEmpty ? m.phone : '-'),
              TextCellValue(m.whatsapp.isNotEmpty ? m.whatsapp : '-'),
              TextCellValue(m.email.isNotEmpty ? m.email : '-'),
              TextCellValue(m.nativeHome.isNotEmpty ? m.nativeHome : '-'),
              TextCellValue(m.gotra.isNotEmpty ? m.gotra : '-'),
              TextCellValue(m.education.isNotEmpty ? m.education : '-'),
              TextCellValue(m.address.isNotEmpty ? m.address : '-'),
              TextCellValue(m.isActive ? 'Active' : 'Inactive'),
            ]);
          }
        }
      }

      final fileBytes = excel.encode();
      if (fileBytes == null) return;

      final fileName = '${title.replaceAll(' ', '_')}_Export.xlsx';

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(fileBytes),
          filename: fileName,
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          text: '$title Excel Export',
        );
      }
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
    }
  }

  /// Export families and members data to PDF document
  static Future<void> exportToPdf({
    required String title,
    required List<Map<String, dynamic>> familiesData,
  }) async {
    try {
      final pdf = pw.Document();

      final List<Map<String, String>> rows = [];
      for (final fam in familiesData) {
        final familyId = fam['familyId']?.toString() ?? '-';
        final familyName = fam['familyName']?.toString() ?? 'Family';
        final List<MemberModel> members = fam['members'] as List<MemberModel>? ?? [];

        for (final m in members) {
          rows.add({
            'famId': familyId,
            'famName': familyName,
            'mid': m.mid,
            'name': '${m.fullName} ${m.surname}'.trim(),
            'phone': m.phone,
            'blood': m.bloodGroup,
            'native': m.nativeHome,
            'education': m.education,
          });
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'RAMANAGARA PATIDAR SAMAJ',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800,
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$title - Official Directory',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.teal700),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Ramanagara Patidar Samaj App', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: ['Fam ID', 'Family Name', 'MID', 'Member Name', 'Phone', 'Blood Group', 'Native Home', 'Education'],
              data: rows.map((r) => [
                r['famId'] ?? '-',
                r['famName'] ?? '-',
                r['mid'] ?? '-',
                r['name'] ?? '-',
                r['phone'] ?? '-',
                r['blood'] ?? '-',
                r['native'] ?? '-',
                r['education'] ?? '-',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = '${title.replaceAll(' ', '_')}_Directory.pdf';

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
    }
  }
}
