import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/seki_model.dart';
import 'auth_service.dart';

class ImportExportService {
  /// Export devices to CSV format
  static Future<String?> exportToCSV(List<Seki> devices) async {
    try {
      // Create CSV content
      final csvBuffer = StringBuffer();
      
      // Add header row
      csvBuffer.writeln('Device Name,Device Type,Start Year,End Year,Start Date,End Date,Precise Mode,Note,Created At');
      
      // Add data rows
      for (final device in devices) {
        final deviceName = _escapeCsvField(device.deviceName);
        final deviceType = _escapeCsvField(device.deviceType);
        final startYear = device.startYear.toString();
        final endYear = device.endYear?.toString() ?? 'Present';
        final startDate = device.startTime != null 
            ? '${device.startTime!.toDate().year}/${device.startTime!.toDate().month}/${device.startTime!.toDate().day}'
            : '';
        final endDate = device.endTime != null
            ? '${device.endTime!.toDate().year}/${device.endTime!.toDate().month}/${device.endTime!.toDate().day}'
            : (device.endYear == null ? 'Present' : '');
        final isPreciseMode = device.isPreciseMode ? 'Yes' : 'No';
        final note = _escapeCsvField(device.note);
        final createdAt = device.createdAt.toDate().toString();
        
        csvBuffer.writeln('$deviceName,$deviceType,$startYear,$endYear,$startDate,$endDate,$isPreciseMode,$note,$createdAt');
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
          
          if (fields.length < 9) {
            failCount++;
            errors.add('Row ${i + 2}: Insufficient fields');
            continue;
          }
          
          final deviceName = fields[0].trim();
          final deviceType = fields[1].trim();
          final startYearStr = fields[2].trim();
          final endYearStr = fields[3].trim();
          final startDateStr = fields[4].trim();
          final endDateStr = fields[5].trim();
          final isPreciseModeStr = fields[6].trim();
          final note = fields[7].trim();
          
          if (deviceName.isEmpty) {
            failCount++;
            errors.add('Row ${i + 2}: Device name cannot be empty');
            continue;
          }
          
          // Parse dates
          final isPreciseMode = isPreciseModeStr == 'Yes' || isPreciseModeStr == 'true' || isPreciseModeStr == '1';
          int startYear;
          int? endYear;
          Timestamp? startTime;
          Timestamp? endTime;
          
          if (isPreciseMode && startDateStr.isNotEmpty) {
            // Parse precise date
            try {
              final startDateParts = startDateStr.split('/');
              if (startDateParts.length == 3) {
                startYear = int.parse(startDateParts[0]);
                final startMonth = int.parse(startDateParts[1]);
                final startDay = int.parse(startDateParts[2]);
                startTime = Timestamp.fromDate(DateTime(startYear, startMonth, startDay));
              } else {
                throw Exception('Date format error');
              }
              
              if (endDateStr.isNotEmpty && endDateStr != 'Present') {
                final endDateParts = endDateStr.split('/');
                if (endDateParts.length == 3) {
                  endYear = int.parse(endDateParts[0]);
                  final endMonth = int.parse(endDateParts[1]);
                  final endDay = int.parse(endDateParts[2]);
                  endTime = Timestamp.fromDate(DateTime(endYear, endMonth, endDay));
                }
              }
            } catch (e) {
              failCount++;
              errors.add('Row ${i + 2}: Date parsing error - $e');
              continue;
            }
          } else {
            // Parse year
            try {
              startYear = int.parse(startYearStr);
              if (endYearStr.isNotEmpty && endYearStr != 'Present') {
                endYear = int.parse(endYearStr);
              }
            } catch (e) {
              failCount++;
              errors.add('Row ${i + 2}: Year parsing error');
              continue;
            }
          }
          
          // Create device data
          final Map<String, dynamic> deviceData = {
            'uid': uid,
            'username': username,
            'deviceName': deviceName,
            'deviceType': deviceType,
            'isPreciseMode': isPreciseMode,
            'createdAt': FieldValue.serverTimestamp(),
            'note': note,
          };
          
          if (isPreciseMode) {
            deviceData['startTime'] = startTime ?? Timestamp.fromDate(DateTime(startYear, 1, 1));
            deviceData['endTime'] = endTime;
            deviceData['startYear'] = startYear;
            deviceData['endYear'] = endYear;
          } else {
            deviceData['startYear'] = startYear;
            deviceData['endYear'] = endYear;
          }
          
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
