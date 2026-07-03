import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../models/point_adjustment_model.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../core/utils/date_helper.dart';
import '../core/constants/app_constants.dart';

class AttendanceProvider extends ChangeNotifier {
  final LocalDbService _local;
  final SyncService _sync;
  static const _uuid = Uuid();

  AttendanceProvider(this._local, this._sync) {
    _sync.onDataChanged.listen((_) => notifyListeners());
  }

  Map<String, bool> getAttendanceMap(DateTime date, String activity) {
    final dateKey = DateHelper.dateKey(date);
    final records = _local.getAttendanceForActivity(dateKey, activity);
    return {for (final r in records) r.studentId: r.isPresent};
  }

  Future<void> saveAttendance({
    required DateTime date,
    required String activity,
    required Map<String, bool> studentPresence,
    Map<String, String>? notes,
  }) async {
    final dateKey = DateHelper.dateKey(date);
    final now = DateTime.now();
    final records = studentPresence.entries.map((e) => AttendanceRecord(
      id: AttendanceRecord.buildId(e.key, dateKey, activity),
      studentId: e.key, dateKey: dateKey, activity: activity,
      isPresent: e.value, note: notes?[e.key] ?? '',
      updatedAt: now, needsSync: true,
    )).toList();
    await _local.saveAttendanceBatch(records);
    notifyListeners();
    _sync.syncNow();
  }

  Future<void> markSingle({
    required String studentId, required DateTime date,
    required String activity, required bool isPresent, String note = '',
  }) async {
    final record = AttendanceRecord(
      id: AttendanceRecord.buildId(studentId, DateHelper.dateKey(date), activity),
      studentId: studentId, dateKey: DateHelper.dateKey(date),
      activity: activity, isPresent: isPresent, note: note.trim(),
      updatedAt: DateTime.now(), needsSync: true,
    );
    await _local.saveAttendanceRecord(record);
    notifyListeners();
    _sync.syncNow();
  }

  List<AttendanceRecord> getAttendanceForDate(DateTime date) =>
      _local.getAttendanceForDate(DateHelper.dateKey(date));

  List<AttendanceRecord> getAttendanceForStudent(String studentId) =>
      _local.getAttendanceForStudent(studentId);

  // -------- النقاط والإحصائيات --------

  /// إجمالي نقاط الحضور (بدون التعديلات اليدوية)
  int attendancePoints(String studentId) {
    return _local.getAttendanceForStudent(studentId).fold(0, (s, r) => s + r.points);
  }

  /// إجمالي التعديلات اليدوية (إضافة + خصم)
  int adjustmentPoints(String studentId) {
    return _local.getAdjustmentsForStudent(studentId).fold(0, (s, a) => s + a.delta);
  }

  /// إجمالي النقاط الكلي (حضور + تعديلات)
  int totalPoints(String studentId) => attendancePoints(studentId) + adjustmentPoints(studentId);

  /// إضافة أو خصم نقاط يدويًا
  Future<void> addPointAdjustment({
    required String studentId,
    required int delta,
    required String reason,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final adj = PointAdjustment(
      id: _uuid.v4(),
      studentId: studentId,
      delta: delta,
      reason: reason.trim(),
      dateKey: DateHelper.dateKey(now),
      createdBy: createdBy,
      createdAt: now,
      needsSync: true,
    );
    await _local.saveAdjustment(adj);
    notifyListeners();
    _sync.syncNow();
  }

  List<PointAdjustment> getAdjustmentsForStudent(String studentId) =>
      _local.getAdjustmentsForStudent(studentId);

  ({int present, int absent, double percentage}) studentStats(String studentId) {
    final records = getAttendanceForStudent(studentId);
    final present = records.where((r) => r.isPresent).length;
    final absent  = records.where((r) => !r.isPresent).length;
    final total   = present + absent;
    return (present: present, absent: absent, percentage: total == 0 ? 0.0 : (present / total) * 100);
  }

  AttendanceRecord? lastAttendance(String studentId) {
    final records = getAttendanceForStudent(studentId).where((r) => r.isPresent).toList();
    if (records.isEmpty) return null;
    records.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return records.first;
  }

  List<AttendanceRecord> absenceLog(String studentId) =>
      getAttendanceForStudent(studentId).where((r) => !r.isPresent).toList();

  int absentDaysCount(String studentId) =>
      absenceLog(studentId).map((r) => r.dateKey).toSet().length;

  bool isAbsentToday(String studentId) {
    final today = DateHelper.dateKey(DateTime.now());
    return absenceLog(studentId).any((r) => r.dateKey == today);
  }

  List<String> missingCategories(String studentId) {
    final records = getAttendanceForStudent(studentId);
    final List<String> missing = [];
    for (final cat in AppConstants.attendanceCategories) {
      final catRecords = records.where((r) => r.activity.contains(cat)).toList();
      if (catRecords.isEmpty) continue;
      catRecords.sort((a, b) => b.dateKey.compareTo(a.dateKey));
      if (!catRecords.first.isPresent) missing.add(cat);
    }
    return missing;
  }

  /// الشباب الغائبين في آخر يوم تم فيه تسجيل حضور
  List<StudentModel> getLastSessionAbsent(List<StudentModel> students) {
    final lastKey = _local.getLastRecordedDateKey();
    if (lastKey == null) return [];
    final lastRecords = _local.getAttendanceForDate(lastKey);
    final absentIds = lastRecords.where((r) => !r.isPresent).map((r) => r.studentId).toSet();
    return students.where((s) => absentIds.contains(s.id)).toList();
  }

  ({int present, int absent, double percentage}) dayStats(DateTime date) {
    final records = getAttendanceForDate(date);
    final present = records.where((r) => r.isPresent).length;
    final absent  = records.where((r) => !r.isPresent).length;
    final total   = present + absent;
    return (present: present, absent: absent, percentage: total == 0 ? 0.0 : (present / total) * 100);
  }

  List<MapEntry<StudentModel, double>> topCommitted(List<StudentModel> students, {int limit = 10}) {
    final list = students.map((s) => MapEntry(s, studentStats(s.id).percentage)).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).toList();
  }

  List<MapEntry<StudentModel, int>> mostAbsent(List<StudentModel> students, {int limit = 10}) {
    final list = students.map((s) => MapEntry(s, studentStats(s.id).absent)).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).toList();
  }

  Map<String, double> activityAttendanceRates(List<String> activities) {
    final all = _local.getAllAttendance();
    return {
      for (final activity in activities)
        activity: () {
          final records = all.where((r) => r.activity == activity).toList();
          if (records.isEmpty) return 0.0;
          return (records.where((r) => r.isPresent).length / records.length) * 100;
        }()
    };
  }

  List<MapEntry<String, double>> attendanceOverTime({int days = 14}) {
    final all = _local.getAllAttendance();
    final Map<String, List<AttendanceRecord>> byDate = {};
    for (final r in all) byDate.putIfAbsent(r.dateKey, () => []).add(r);
    final sortedKeys = byDate.keys.toList()..sort();
    final lastKeys = sortedKeys.length > days ? sortedKeys.sublist(sortedKeys.length - days) : sortedKeys;
    return lastKeys.map((key) {
      final records = byDate[key]!;
      final present = records.where((r) => r.isPresent).length;
      return MapEntry(key, records.isEmpty ? 0.0 : (present / records.length) * 100);
    }).toList();
  }
}

  /// كل سجلات الحضور (بدون محذوفة)
  List<AttendanceRecord> getAll() => _local.getAllAttendance();
