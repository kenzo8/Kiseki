import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/seki_model.dart';
import 'auth_service.dart';

enum ExportFormat {
  csv,
  xlsx,
}

class ImportExportService {
  /// Export devices to CSV format
  static Future<String?> exportToCSV(List<Seki> devices) async {
    try {
      // Create CSV content
      final csvBuffer = StringBuffer();
      
      // Add header row - unified format using dates only
      csvBuffer.writeln('Device Name,Device Type,Start Date,End Date,Note,Created At');
      
      // Add data rows
      for (final device in devices) {
        final deviceName = _escapeCsvField(device.deviceName);
        final deviceType = _escapeCsvField(device.deviceType);
        
        // ISO-style date for compatibility (YYYY-MM-DD or YYYY for year-only)
        String startDate;
        if (device.startTime != null) {
          final date = device.startTime!.toDate();
          startDate = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else {
          startDate = '${device.startYear}';
        }
        String endDate;
        if (device.endTime != null) {
          final date = device.endTime!.toDate();
          endDate = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else if (device.endYear != null) {
          endDate = '${device.endYear}';
        } else {
          endDate = 'Present';
        }
        final note = _escapeCsvField(device.note);
        final createdAt = device.createdAt.toDate().toIso8601String();
        csvBuffer.writeln('$deviceName,$deviceType,$startDate,$endDate,$note,$createdAt');
      }
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${directory.path}/devices_export_$timestamp.csv');
      await file.writeAsString(csvBuffer.toString());
      
      return file.path;
    } catch (e) {
      debugPrint('Export error: $e');
      return null;
    }
  }

  /// Export devices to XLSX format
  static Future<String?> exportToXLSX(List<Seki> devices) async {
    try {
      final excel = Excel.createExcel();
      // Create Devices sheet first, then remove default sheet(s) so only Devices remains
      final sheet = excel['Devices'];
      for (final name in excel.tables.keys.toList()) {
        if (name != 'Devices') {
          excel.delete(name);
        }
      }
      
      // Add header row using TextCellValue
      sheet.appendRow([
        TextCellValue('Device Name'),
        TextCellValue('Device Type'),
        TextCellValue('Start Date'),
        TextCellValue('End Date'),
        TextCellValue('Note'),
        TextCellValue('Created At'),
      ]);
      
      // Style header row (if supported by excel package version)
      try {
        final headerStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
        );
        for (int i = 0; i < 6; i++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          cell.cellStyle = headerStyle;
        }
      } catch (e) {
        // Style not supported in this version, skip
        debugPrint('Header styling not available: $e');
      }
      
      // Add data rows - ISO date format for compatibility
      for (final device in devices) {
        String startDate;
        if (device.startTime != null) {
          final date = device.startTime!.toDate();
          startDate = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else {
          startDate = '${device.startYear}';
        }
        String endDate;
        if (device.endTime != null) {
          final date = device.endTime!.toDate();
          endDate = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else if (device.endYear != null) {
          endDate = '${device.endYear}';
        } else {
          endDate = 'Present';
        }
        final createdAt = device.createdAt.toDate().toIso8601String();
        sheet.appendRow([
          TextCellValue(device.deviceName),
          TextCellValue(device.deviceType),
          TextCellValue(startDate),
          TextCellValue(endDate),
          TextCellValue(device.note),
          TextCellValue(createdAt),
        ]);
      }
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${directory.path}/devices_export_$timestamp.xlsx');
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return file.path;
      }
      return null;
    } catch (e) {
      debugPrint('Export XLSX error: $e');
      return null;
    }
  }

  /// Export devices to specified format (CSV or XLSX)
  static Future<String?> export(List<Seki> devices, ExportFormat format) async {
    switch (format) {
      case ExportFormat.csv:
        return await exportToCSV(devices);
      case ExportFormat.xlsx:
        return await exportToXLSX(devices);
    }
  }
  
  /// Import devices from CSV file
  static Future<ImportResult> importFromCSV(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(success: false, message: 'File does not exist');
      }
      
      final content = await file.readAsString();
      final lines = content.split('\n');
      
      if (lines.isEmpty) {
        return ImportResult(success: false, message: 'File is empty');
      }
      
      // Skip header row
      final dataLines = lines.skip(1).where((line) => line.trim().isNotEmpty).toList();
      
      if (dataLines.isEmpty) {
        return ImportResult(success: false, message: 'No data rows');
      }
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return ImportResult(success: false, message: 'Not logged in');
      }
      
      final uid = currentUser.uid;
      String username;
      try {
        final authService = AuthService();
        final userProfile = await authService.getUserProfile(uid);
        if (userProfile != null && userProfile['username'] != null) {
          username = userProfile['username'] as String;
        } else {
          final userEmail = currentUser.email;
          if (userEmail != null) {
            username = authService.generateDefaultUsername(userEmail);
          } else {
            username = 'user${uid.substring(0, 4)}';
          }
        }
      } catch (e) {
        final userEmail = currentUser.email;
        if (userEmail != null) {
          final authService = AuthService();
          username = authService.generateDefaultUsername(userEmail);
        } else {
          username = 'user${uid.substring(0, 4)}';
        }
      }
      
      int successCount = 0;
      int failCount = 0;
      final errors = <String>[];
      
      for (int i = 0; i < dataLines.length; i++) {
        try {
          final line = dataLines[i];
          final fields = _parseCsvLine(line);
          
          // Support both old format (9 fields) and new format (6 fields)
          if (fields.length < 6) {
            failCount++;
            errors.add('Row ${i + 2}: Insufficient fields (expected at least 6)');
            continue;
          }
          
          String deviceName;
          String deviceType;
          String startDateStr;
          String endDateStr;
          String note;
          String createdAtStr = ''; // Optional Created At field
          
          // Check if old format (with Year columns) or new format
          if (fields.length >= 9) {
            // Old format: Device Name,Device Type,Start Year,End Year,Start Date,End Date,Precise Mode,Note,Created At
            deviceName = fields[0].trim();
            deviceType = fields[1].trim();
            // Prefer Start Date over Start Year
            startDateStr = fields[4].trim().isNotEmpty ? fields[4].trim() : fields[2].trim();
            endDateStr = fields[5].trim().isNotEmpty && fields[5].trim() != 'Present' 
                ? fields[5].trim() 
                : (fields[3].trim().isNotEmpty && fields[3].trim() != 'Present' ? fields[3].trim() : 'Present');
            note = fields[7].trim();
            createdAtStr = fields.length > 8 ? fields[8].trim() : '';
          } else {
            // New format: Device Name,Device Type,Start Date,End Date,Note,Created At
            deviceName = fields[0].trim();
            deviceType = fields[1].trim();
            startDateStr = fields[2].trim();
            endDateStr = fields[3].trim();
            note = fields[4].trim();
            createdAtStr = fields.length > 5 ? fields[5].trim() : '';
          }
          
          if (deviceName.isEmpty) {
            failCount++;
            errors.add('Row ${i + 2}: Device name cannot be empty');
            continue;
          }
          
          // Unified date parsing with time compatibility (ISO, YYYY-MM-DD, Excel serial, year-only)
          int startYear;
          int? endYear;
          Timestamp? startTime;
          Timestamp? endTime;
          
          final startDt = _parseDateString(startDateStr, forEndDate: false);
          if (startDt == null) {
            failCount++;
            errors.add(startDateStr.isEmpty
                ? 'Row ${i + 2}: Start date cannot be empty'
                : 'Row ${i + 2}: Invalid start date format: $startDateStr');
            continue;
          }
          startYear = startDt.year;
          startTime = Timestamp.fromDate(startDt);

          if (endDateStr.isEmpty || endDateStr.trim().toLowerCase() == 'present') {
            endTime = null;
            endYear = null;
          } else {
            final endDt = _parseDateString(endDateStr, forEndDate: true);
            if (endDt == null) {
              failCount++;
              errors.add('Row ${i + 2}: Invalid end date format: $endDateStr');
              continue;
            }
            endYear = endDt.year;
            endTime = Timestamp.fromDate(endDt);
          }

          dynamic createdAt;
          final createdAtParsed = _parseCreatedAtString(createdAtStr);
          createdAt = createdAtParsed != null
              ? Timestamp.fromDate(createdAtParsed)
              : FieldValue.serverTimestamp();
          
          // Create device data - always use precise mode
          final Map<String, dynamic> deviceData = {
            'uid': uid,
            'username': username,
            'deviceName': deviceName,
            'deviceType': deviceType,
            'isPreciseMode': true, // Always use precise mode
            'startTime': startTime,
            'endTime': endTime,
            'startYear': startYear, // Also save for backward compatibility
            'endYear': endYear,
            'createdAt': createdAt,
            'note': note,
          };
          
          await FirebaseFirestore.instance.collection('seki').add(deviceData);
          successCount++;
        } catch (e) {
          failCount++;
            errors.add('Row ${i + 2}: $e');
        }
      }
      
      return ImportResult(
        success: successCount > 0,
        message: 'Successfully imported $successCount, failed $failCount',
        successCount: successCount,
        failCount: failCount,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Import error: $e');
    }
  }

  /// Import devices from XLSX file
  static Future<ImportResult> importFromXLSX(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(success: false, message: 'File does not exist');
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return ImportResult(success: false, message: 'No sheets found in Excel file');
      }

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        return ImportResult(success: false, message: 'Sheet is empty');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return ImportResult(success: false, message: 'Not logged in');
      }

      final uid = currentUser.uid;
      String username;
      try {
        final authService = AuthService();
        final userProfile = await authService.getUserProfile(uid);
        if (userProfile != null && userProfile['username'] != null) {
          username = userProfile['username'] as String;
        } else {
          final userEmail = currentUser.email;
          if (userEmail != null) {
            username = authService.generateDefaultUsername(userEmail);
          } else {
            username = 'user${uid.substring(0, 4)}';
          }
        }
      } catch (e) {
        final userEmail = currentUser.email;
        if (userEmail != null) {
          final authService = AuthService();
          username = authService.generateDefaultUsername(userEmail);
        } else {
          username = 'user${uid.substring(0, 4)}';
        }
      }

      int successCount = 0;
      int failCount = 0;
      final errors = <String>[];

      // Skip header row (row 0)
      for (int i = 1; i < sheet.rows.length; i++) {
        try {
          final row = sheet.rows[i];
          if (row.isEmpty || row.length < 6) {
            failCount++;
            errors.add('Row ${i + 1}: Insufficient fields');
            continue;
          }

          // Extract fields from Excel row
          final deviceName = _getCellValueFromRow(row, 0)?.trim() ?? '';
          final deviceType = _getCellValueFromRow(row, 1)?.trim() ?? '';
          final startDateStr = _getCellValueFromRow(row, 2)?.trim() ?? '';
          final endDateStr = _getCellValueFromRow(row, 3)?.trim() ?? '';
          final note = _getCellValueFromRow(row, 4)?.trim() ?? '';
          final createdAtStr = row.length > 5 ? (_getCellValueFromRow(row, 5)?.trim() ?? '') : '';

          if (deviceName.isEmpty) {
            failCount++;
            errors.add('Row ${i + 1}: Device name cannot be empty');
            continue;
          }

          // Unified date parsing with time compatibility (ISO, Excel serial, year-only)
          int startYear;
          int? endYear;
          Timestamp? startTime;
          Timestamp? endTime;

          final startDt = _parseDateString(startDateStr, forEndDate: false);
          if (startDt == null) {
            failCount++;
            errors.add(startDateStr.isEmpty
                ? 'Row ${i + 1}: Start date cannot be empty'
                : 'Row ${i + 1}: Invalid start date format: $startDateStr');
            continue;
          }
          startYear = startDt.year;
          startTime = Timestamp.fromDate(startDt);

          if (endDateStr.isEmpty || endDateStr.trim().toLowerCase() == 'present') {
            endTime = null;
            endYear = null;
          } else {
            final endDt = _parseDateString(endDateStr, forEndDate: true);
            if (endDt == null) {
              failCount++;
              errors.add('Row ${i + 1}: Invalid end date format: $endDateStr');
              continue;
            }
            endYear = endDt.year;
            endTime = Timestamp.fromDate(endDt);
          }

          dynamic createdAt;
          final createdAtParsed = _parseCreatedAtString(createdAtStr);
          createdAt = createdAtParsed != null
              ? Timestamp.fromDate(createdAtParsed)
              : FieldValue.serverTimestamp();

          // Create device data
          final Map<String, dynamic> deviceData = {
            'uid': uid,
            'username': username,
            'deviceName': deviceName,
            'deviceType': deviceType,
            'isPreciseMode': true,
            'startTime': startTime,
            'endTime': endTime,
            'startYear': startYear,
            'endYear': endYear,
            'createdAt': createdAt,
            'note': note,
          };

          await FirebaseFirestore.instance.collection('seki').add(deviceData);
          successCount++;
        } catch (e) {
          failCount++;
          errors.add('Row ${i + 1}: $e');
        }
      }

      return ImportResult(
        success: successCount > 0,
        message: 'Successfully imported $successCount, failed $failCount',
        successCount: successCount,
        failCount: failCount,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Import error: $e');
    }
  }

  /// Import devices from file (auto-detect format by extension)
  static Future<ImportResult> importFromFile(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    if (extension == 'xlsx') {
      return await importFromXLSX(filePath);
    } else {
      return await importFromCSV(filePath);
    }
  }

  /// Parse date string with multiple format compatibility (ISO, YYYY/MM/DD, YYYY-MM-DD, Excel serial, year-only).
  /// [forEndDate] true: year-only becomes Dec 31; false: year-only becomes Jan 1.
  static DateTime? _parseDateString(String s, {bool forEndDate = false}) {
    final raw = s.trim();
    if (raw.isEmpty) return null;
    // Excel serial number (1 = 1900-01-01; fractional part = time of day)
    final serial = double.tryParse(raw);
    if (serial != null && serial >= 1 && serial < 300000) {
      final excelEpoch = DateTime(1899, 12, 31);
      final days = serial.floor();
      final fraction = serial - days;
      final duration = Duration(
        days: days,
        microseconds: (fraction * 24 * 60 * 60 * 1000000).round(),
      );
      return excelEpoch.add(duration);
    }
    // DateTime.parse handles ISO 8601 and many formats
    try {
      final dt = DateTime.parse(raw);
      if (dt.year > 1900 && dt.year < 2100) return dt;
    } catch (_) {}
    // YYYY/MM/DD or YYYY/-/- or YYYY
    final slashParts = raw.split('/');
    if (slashParts.length == 3) {
      final y = int.tryParse(slashParts[0].trim());
      if (y == null) return null;
      if (slashParts[1].trim() == '-' && slashParts[2].trim() == '-') {
        return forEndDate ? DateTime(y, 12, 31) : DateTime(y, 1, 1);
      }
      final m = int.tryParse(slashParts[1].trim());
      final d = int.tryParse(slashParts[2].trim());
      if (m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    } else if (slashParts.length == 1) {
      final y = int.tryParse(slashParts[0].trim());
      if (y != null && y > 1900 && y < 2100) {
        return forEndDate ? DateTime(y, 12, 31) : DateTime(y, 1, 1);
      }
    }
    // YYYY-MM-DD or YYYY.MM.DD
    final dashParts = raw.split(RegExp(r'[-.]'));
    if (dashParts.length == 3) {
      final y = int.tryParse(dashParts[0].trim());
      final m = int.tryParse(dashParts[1].trim());
      final d = int.tryParse(dashParts[2].trim());
      if (y != null && m != null && d != null && y > 1900 && y < 2100 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
      if (y != null && dashParts[1].trim() == '-' && dashParts[2].trim() == '-') {
        return forEndDate ? DateTime(y, 12, 31) : DateTime(y, 1, 1);
      }
    }
    return null;
  }

  /// Parse Created At string (ISO 8601, date-only, Excel serial).
  static DateTime? _parseCreatedAtString(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final serial = double.tryParse(t);
    if (serial != null && serial >= 1 && serial < 300000) {
      final excelEpoch = DateTime(1899, 12, 31);
      final days = serial.floor();
      final fraction = serial - days;
      final duration = Duration(
        days: days,
        microseconds: (fraction * 24 * 60 * 60 * 1000000).round(),
      );
      return excelEpoch.add(duration);
    }
    try {
      return DateTime.parse(t);
    } catch (_) {}
    return _parseDateString(t, forEndDate: false);
  }

  /// Get cell value as string from Excel row
  static String? _getCellValueFromRow(List<dynamic> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null) return null;
    
    // Handle CellValue types from excel 4.0.6
    try {
      // Check if it's a CellValue type
      if (cell is CellValue) {
        // Handle different CellValue subtypes
        if (cell is TextCellValue) {
          // TextCellValue.value returns TextSpan, need to get text
          return cell.value.text ?? '';
        } else if (cell is IntCellValue) {
          return cell.value.toString();
        } else if (cell is DoubleCellValue) {
          return cell.value.toString();
        } else if (cell is DateCellValue) {
          // DateCellValue structure may vary, use toString as fallback
          return cell.toString();
        } else {
          return cell.toString();
        }
      }
      
      // Fallback: try to get value property
      try {
        final value = cell.value;
        if (value == null) return null;
        if (value is String) return value;
        if (value is int || value is double) return value.toString();
        if (value is DateTime) return value.toString();
        return value.toString();
      } catch (_) {}
      
      // Last resort: convert to string
      return cell.toString();
    } catch (e) {
      debugPrint('Error getting cell value: $e');
      return null;
    }
  }
  
  /// Escape CSV field (handle commas and quotes)
  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
  
  /// Parse CSV line (handle quoted fields)
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          buffer.write('"');
          i++; // Skip next quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // Field separator
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    // Add last field
    result.add(buffer.toString());
    
    return result;
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int successCount;
  final int failCount;
  final List<String> errors;
  
  ImportResult({
    required this.success,
    required this.message,
    this.successCount = 0,
    this.failCount = 0,
    this.errors = const [],
  });
}
