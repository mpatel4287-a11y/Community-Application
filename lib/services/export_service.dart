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

enum ExportField {
  familyId('familyId', 'YSK Family ID'),
  familyName('familyName', 'Family Name'),
  mid('mid', 'MID'),
  fullName('fullName', 'Name'),
  phone('phone', 'Phone Number'),
  bloodGroup('bloodGroup', 'Blood Group'),
  age('age', 'Age'),
  gender('gender', 'Gender'),
  fatherName('fatherName', 'Father Name'),
  marriageStatus('marriageStatus', 'Marriage Status'),
  motherName('motherName', 'Mother Name'),
  nativeHome('nativeHome', 'Native Home'),
  education('education', 'Education'),
  address('address', 'Address'),
  email('email', 'Email');

  final String id;
  final String label;
  const ExportField(this.id, this.label);

  String getValue(Map<String, dynamic> famData, MemberModel m) {
    switch (this) {
      case ExportField.familyId:
        final idVal = famData['familyId']?.toString();
        return (idVal != null && idVal.isNotEmpty && idVal != '-')
            ? idVal
            : (m.familyId.isNotEmpty ? m.familyId : '-');
      case ExportField.familyName:
        final famName = famData['familyName']?.toString();
        return (famName != null && famName.isNotEmpty) ? famName : m.familyName;
      case ExportField.mid:
        return m.mid.isNotEmpty ? m.mid : '-';
      case ExportField.fullName:
        final name = '${m.fullName} ${m.surname}'.trim();
        return name.isNotEmpty ? name : '-';
      case ExportField.phone:
        return m.phone.isNotEmpty ? m.phone : '-';
      case ExportField.bloodGroup:
        return m.bloodGroup.isNotEmpty ? m.bloodGroup : '-';
      case ExportField.age:
        return m.age > 0 ? '${m.age}' : '-';
      case ExportField.gender:
        return m.gender.isNotEmpty ? m.gender : '-';
      case ExportField.fatherName:
        return m.fatherName.isNotEmpty ? m.fatherName : '-';
      case ExportField.marriageStatus:
        return m.marriageStatus.isNotEmpty ? m.marriageStatus : 'Unmarried';
      case ExportField.motherName:
        return m.motherName.isNotEmpty ? m.motherName : '-';
      case ExportField.nativeHome:
        return m.nativeHome.isNotEmpty ? m.nativeHome : '-';
      case ExportField.education:
        return m.education.isNotEmpty ? m.education : '-';
      case ExportField.address:
        return m.address.isNotEmpty ? m.address : '-';
      case ExportField.email:
        return m.email.isNotEmpty ? m.email : '-';
    }
  }
}

class ExportService {
  static const List<ExportField> defaultFields = [
    ExportField.familyId,
    ExportField.familyName,
    ExportField.mid,
    ExportField.fullName,
    ExportField.phone,
    ExportField.bloodGroup,
    ExportField.age,
    ExportField.gender,
    ExportField.fatherName,
    ExportField.marriageStatus,
  ];

  /// Export families and members data to an Excel (.xlsx) file with custom selected fields
  static Future<void> exportToExcel({
    required String title,
    required List<Map<String, dynamic>> familiesData,
    List<ExportField>? selectedFields,
  }) async {
    try {
      final fields = (selectedFields != null && selectedFields.isNotEmpty)
          ? selectedFields
          : defaultFields;

      final excel = Excel.createExcel();
      final Sheet sheet = excel['Family Details'];
      excel.setDefaultSheet('Family Details');

      // Header style
      final CellStyle headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      );

      // Add Column Headers
      for (int i = 0; i < fields.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(fields[i].label);
        cell.cellStyle = headerStyle;
      }

      // Add Data Rows
      for (final fam in familiesData) {
        final List<MemberModel> members = fam['members'] as List<MemberModel>? ?? [];

        if (members.isEmpty) {
          final rowCells = fields.map((f) {
            if (f == ExportField.familyId) {
              return TextCellValue(fam['familyId']?.toString() ?? '-');
            } else if (f == ExportField.familyName) {
              return TextCellValue(fam['familyName']?.toString() ?? 'Family');
            }
            return TextCellValue('-');
          }).toList();

          sheet.appendRow(rowCells);
        } else {
          for (final m in members) {
            final rowCells = fields
                .map((f) => TextCellValue(f.getValue(fam, m)))
                .toList();

            sheet.appendRow(rowCells);
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

  /// Export families and members data to PDF document with custom selected fields
  static Future<void> exportToPdf({
    required String title,
    required List<Map<String, dynamic>> familiesData,
    List<ExportField>? selectedFields,
  }) async {
    try {
      final fields = (selectedFields != null && selectedFields.isNotEmpty)
          ? selectedFields
          : defaultFields;

      final pdf = pw.Document();

      final List<List<String>> dataRows = [];
      for (final fam in familiesData) {
        final List<MemberModel> members = fam['members'] as List<MemberModel>? ?? [];
        for (final m in members) {
          dataRows.add(fields.map((f) => f.getValue(fam, m)).toList());
        }
      }

      final headers = fields.map((f) => f.label).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: fields.length > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'RAMANAGARA PATIDAR SAMAJ',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800,
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                '$title - Official Directory',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.teal700),
              pw.SizedBox(height: 6),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Ramanagara Patidar Samaj App', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: dataRows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
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
