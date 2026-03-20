import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/user.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  Map<String, String> _getUserDataMap(AppUser user) {
    return {
      'Username': user.username,
      'First Name': user.firstName,
      'Middle Name': user.middleName ?? 'N/A',
      'Last Name': user.lastName,
      'Email': user.email,
      'Phone Number': user.phoneNumber ?? 'N/A',
      'Country Code': user.countryCode ?? 'N/A',
      'Gender': user.gender ?? 'N/A',
      'Date of Birth': _formatDate(user.dateOfBirth),
      'KCC': user.kcc ?? 'N/A',
      'Department': user.department ?? 'N/A',
      'Membership Status': user.membershipStatus ?? 'N/A',
      'Address': user.address ?? 'N/A',
      'Role': user.role,
    };
  }

  Future<String> _getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
  }

  // Export to PDF
  Future<File?> exportToPdf(AppUser user) async {
    try {
      final pdf = pw.Document();
      final userData = _getUserDataMap(user);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'User Profile Data',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${user.firstName} ${user.lastName}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated on: ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                ...userData.entries.map((entry) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 150,
                        child: pw.Text(
                          '${entry.key}:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(entry.value),
                      ),
                    ],
                  ),
                )),
              ],
            );
          },
        ),
      );

      final exportDir = await _getExportDirectory();
      final file = File('$exportDir/user_profile_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      debugPrint('PDF exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      return null;
    }
  }

  // Export to Excel
  Future<File?> exportToExcel(AppUser user) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['User Profile'];
      
      final userData = _getUserDataMap(user);
      
      // Add header
      sheet.appendRow([TextCellValue('Field'), TextCellValue('Value')]);
      
      // Add data
      for (var entry in userData.entries) {
        sheet.appendRow([TextCellValue(entry.key), TextCellValue(entry.value)]);
      }
      
      // Style header
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D4AF37'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
      sheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
      sheet.cell(CellIndex.indexByString('B1')).cellStyle = headerStyle;
      
      // Set column widths
      sheet.setColumnWidth(0, 25);
      sheet.setColumnWidth(1, 40);

      final exportDir = await _getExportDirectory();
      final file = File('$exportDir/user_profile_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        debugPrint('Excel exported to: ${file.path}');
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      return null;
    }
  }

  // Export to CSV
  Future<File?> exportToCsv(AppUser user) async {
    try {
      final userData = _getUserDataMap(user);
      final buffer = StringBuffer();
      
      // Add header
      buffer.writeln('Field,Value');
      
      // Add data
      for (var entry in userData.entries) {
        // Escape values that contain commas or quotes
        final value = entry.value.contains(',') || entry.value.contains('"')
            ? '"${entry.value.replaceAll('"', '""')}"'
            : entry.value;
        buffer.writeln('${entry.key},$value');
      }

      final exportDir = await _getExportDirectory();
      final file = File('$exportDir/user_profile_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());
      debugPrint('CSV exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to CSV: $e');
      return null;
    }
  }

  // Export to Word (DOCX) - Simple text-based approach
  Future<File?> exportToWord(AppUser user) async {
    try {
      final userData = _getUserDataMap(user);
      final buffer = StringBuffer();
      
      buffer.writeln('USER PROFILE DATA');
      buffer.writeln('==================');
      buffer.writeln();
      buffer.writeln('${user.firstName} ${user.lastName}');
      buffer.writeln('Generated on: ${_formatDate(DateTime.now())}');
      buffer.writeln();
      buffer.writeln('-------------------');
      buffer.writeln();
      
      for (var entry in userData.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }

      final exportDir = await _getExportDirectory();
      // Using .doc extension for compatibility (plain text format)
      final file = File('$exportDir/user_profile_${DateTime.now().millisecondsSinceEpoch}.doc');
      await file.writeAsString(buffer.toString());
      debugPrint('Word doc exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to Word: $e');
      return null;
    }
  }

  // Share exported file
  Future<void> shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'User Profile Export',
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
  }

  // Export and share
  Future<bool> exportAndShare(AppUser user, ExportFormat format) async {
    File? file;
    
    switch (format) {
      case ExportFormat.pdf:
        file = await exportToPdf(user);
        break;
      case ExportFormat.excel:
        file = await exportToExcel(user);
        break;
      case ExportFormat.csv:
        file = await exportToCsv(user);
        break;
      case ExportFormat.word:
        file = await exportToWord(user);
        break;
    }
    
    if (file != null) {
      await shareFile(file);
      return true;
    }
    return false;
  }
}

enum ExportFormat { pdf, excel, csv, word }
