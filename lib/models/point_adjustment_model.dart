import 'package:hive/hive.dart';

/// نموذج تعديل نقاط يدوي (إضافة أو خصم)
class PointAdjustment {
  final String id;
  final String studentId;
  final int delta;      // موجب = إضافة، سالب = خصم
  final String reason;  // السبب
  final String dateKey; // yyyy-MM-dd
  final String createdBy;
  final DateTime createdAt;
  bool needsSync;
  bool isDeleted;

  PointAdjustment({
    required this.id,
    required this.studentId,
    required this.delta,
    required this.reason,
    required this.dateKey,
    required this.createdBy,
    required this.createdAt,
    this.needsSync = true,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'studentId': studentId, 'delta': delta,
    'reason': reason, 'dateKey': dateKey, 'createdBy': createdBy,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isDeleted': isDeleted,
  };

  factory PointAdjustment.fromMap(Map<String, dynamic> m) => PointAdjustment(
    id: m['id'] as String, studentId: m['studentId'] as String,
    delta: m['delta'] as int, reason: (m['reason'] as String?) ?? '',
    dateKey: m['dateKey'] as String,
    createdBy: (m['createdBy'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    isDeleted: (m['isDeleted'] as bool?) ?? false,
    needsSync: false,
  );
}

class PointAdjustmentAdapter extends TypeAdapter<PointAdjustment> {
  @override final int typeId = 3;

  @override
  PointAdjustment read(BinaryReader reader) {
    final m = reader.readMap();
    return PointAdjustment(
      id: m['id'] as String, studentId: m['studentId'] as String,
      delta: m['delta'] as int, reason: (m['reason'] as String?) ?? '',
      dateKey: m['dateKey'] as String, createdBy: (m['createdBy'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      isDeleted: (m['isDeleted'] as bool?) ?? false,
      needsSync: (m['needsSync'] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, PointAdjustment obj) {
    writer.writeMap({
      'id': obj.id, 'studentId': obj.studentId, 'delta': obj.delta,
      'reason': obj.reason, 'dateKey': obj.dateKey, 'createdBy': obj.createdBy,
      'createdAt': obj.createdAt.millisecondsSinceEpoch,
      'isDeleted': obj.isDeleted, 'needsSync': obj.needsSync,
    });
  }
}
