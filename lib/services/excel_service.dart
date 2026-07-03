import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/student_model.dart';
import '../core/utils/name_helper.dart';

/// خدمة تصدير/استيراد Excel
/// تنسيق الاستيراد:
///   A = رقم تسلسلي (يُتجاهل)
///   B = الاسم الثلاثي
///   C = العنوان
///   D = العنوان التفصيلي
///   E = تاريخ الميلاد
///   F = رقم تليفون أول (واتساب)
///   G = رقم تليفون تاني
///   باقي الخانات تُتجاهل
class ExcelService {
  static const _uuid = Uuid();

  Future<String> exportStudents(List<StudentModel> students) async {
    final excel = Excel.createExcel();
    final sheet = excel['الشباب'];
    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('الاسم الثلاثي'),
      TextCellValue('العنوان'),
      TextCellValue('العنوان التفصيلي'),
      TextCellValue('تاريخ الميلاد'),
      TextCellValue('رقم تليفون أول (واتساب)'),
      TextCellValue('رقم تليفون تاني'),
      TextCellValue('ملاحظات'),
    ]);
    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s.fullName),
        TextCellValue(s.address),
        TextCellValue(s.addressDetail),
        TextCellValue(s.birthDate),
        TextCellValue(s.phone),
        TextCellValue(s.phone2),
        TextCellValue(s.notes),
      ]);
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/students_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  Future<List<StudentModel>> importStudents(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final List<StudentModel> result = [];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        // B = index 1
        final fullName = (row.length > 1 ? row[1]?.value?.toString().trim() : null) ?? '';
        if (fullName.isEmpty) continue;

        String _cell(int col) =>
            (row.length > col ? row[col]?.value?.toString().trim() : null) ?? '';

        final address      = _cell(2);  // C
        final addressDetail = _cell(3); // D
        final birthDate    = _cell(4);  // E
        final phone        = _cell(5);  // F
        final phone2       = _cell(6);  // G

        final now = DateTime.now();
        result.add(StudentModel(
          id: _uuid.v4(),
          fullName: fullName,
          firstName: NameHelper.extractFirstName(fullName),
          phone: phone,
          phone2: phone2,
          address: address,
          addressDetail: addressDetail,
          birthDate: birthDate,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        ));
      }
    }
    return result;
  }
}
