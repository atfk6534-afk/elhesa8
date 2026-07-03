import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/visit_model.dart';
import '../models/point_adjustment_model.dart';
import '../core/utils/date_helper.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  late Box<StudentModel> _studentsBox;
  late Box<AttendanceRecord> _attendanceBox;
  late Box<VisitRecord> _visitsBox;
  late Box<PointAdjustment> _pointsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(StudentModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(AttendanceRecordAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(VisitRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PointAdjustmentAdapter());
    _studentsBox  = await Hive.openBox<StudentModel>(AppConstants.studentsBox);
    _attendanceBox = await Hive.openBox<AttendanceRecord>(AppConstants.attendanceBox);
    _visitsBox    = await Hive.openBox<VisitRecord>(AppConstants.visitsBox);
    _pointsBox    = await Hive.openBox<PointAdjustment>('points_box');
  }

  // -------- الشباب --------
  List<StudentModel> getAllStudents({bool includeDeleted = false}) {
    final list = _studentsBox.values.toList();
    final f = includeDeleted ? list : list.where((s) => !s.isDeleted).toList();
    f.sort((a, b) => a.firstName.compareTo(b.firstName));
    return f;
  }
  StudentModel? getStudent(String id) => _studentsBox.get(id);
  Future<void> saveStudent(StudentModel s) async => _studentsBox.put(s.id, s);
  Future<void> deleteStudentSoft(String id) async {
    final s = _studentsBox.get(id);
    if (s != null) await _studentsBox.put(id, s.copyWith(isDeleted: true, updatedAt: DateTime.now(), needsSync: true));
  }
  Future<void> purgeStudent(String id) async => _studentsBox.delete(id);
  List<StudentModel> getStudentsNeedingSync() => _studentsBox.values.where((s) => s.needsSync).toList();

  // -------- الحضور --------
  List<AttendanceRecord> getAttendanceForDate(String dateKey) =>
      _attendanceBox.values.where((a) => a.dateKey == dateKey && !a.isDeleted).toList();
  List<AttendanceRecord> getAttendanceForActivity(String dateKey, String activity) =>
      _attendanceBox.values.where((a) => a.dateKey == dateKey && a.activity == activity && !a.isDeleted).toList();
  List<AttendanceRecord> getAttendanceForStudent(String studentId) {
    final list = _attendanceBox.values.where((a) => a.studentId == studentId && !a.isDeleted).toList();
    list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return list;
  }
  List<AttendanceRecord> getAllAttendance({bool includeDeleted = false}) {
    final list = _attendanceBox.values.toList();
    return includeDeleted ? list : list.where((a) => !a.isDeleted).toList();
  }
  Future<void> saveAttendanceRecord(AttendanceRecord r) async => _attendanceBox.put(r.id, r);
  Future<void> saveAttendanceBatch(List<AttendanceRecord> records) async =>
      _attendanceBox.putAll({for (final r in records) r.id: r});
  List<AttendanceRecord> getAttendanceNeedingSync() =>
      _attendanceBox.values.where((a) => a.needsSync).toList();

  /// آخر تاريخ تم تسجيل حضور/غياب فيه لأي نشاط
  String? getLastRecordedDateKey() {
    final keys = _attendanceBox.values.map((a) => a.dateKey).toSet().toList();
    if (keys.isEmpty) return null;
    keys.sort();
    return keys.last;
  }

  // -------- الافتقاد --------
  List<VisitRecord> getVisitsForStudent(String studentId) {
    final list = _visitsBox.values.where((v) => v.studentId == studentId && !v.isDeleted).toList();
    list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return list;
  }
  List<VisitRecord> getAllVisits({bool includeDeleted = false}) {
    final list = _visitsBox.values.toList();
    return includeDeleted ? list : list.where((v) => !v.isDeleted).toList();
  }
  VisitRecord? getVisit(String id) => _visitsBox.get(id);
  Future<void> saveVisit(VisitRecord v) async => _visitsBox.put(v.id, v);
  List<VisitRecord> getVisitsNeedingSync() => _visitsBox.values.where((v) => v.needsSync).toList();

  // -------- تعديلات النقاط --------
  List<PointAdjustment> getAdjustmentsForStudent(String studentId) =>
      _pointsBox.values.where((a) => a.studentId == studentId && !a.isDeleted).toList();
  List<PointAdjustment> getAllAdjustments() =>
      _pointsBox.values.where((a) => !a.isDeleted).toList();
  Future<void> saveAdjustment(PointAdjustment a) async => _pointsBox.put(a.id, a);
  List<PointAdjustment> getAdjustmentsNeedingSync() =>
      _pointsBox.values.where((a) => a.needsSync).toList();

  Future<void> clearAll() async {
    await _studentsBox.clear();
    await _attendanceBox.clear();
    await _visitsBox.clear();
    await _pointsBox.clear();
  }
}
