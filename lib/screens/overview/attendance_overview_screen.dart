import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../models/attendance_model.dart';

/// صفحة نظرة عامة: كل الأيام المسجلة، كام حضر، وتفاصيل كل يوم
class AttendanceOverviewScreen extends StatelessWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final attendPro  = context.watch<AttendanceProvider>();
    final students   = context.watch<StudentProvider>().allStudents;
    final allRecords = attendPro.getAll();

    // تجميع حسب التاريخ
    final Map<String, List<AttendanceRecord>> byDate = {};
    for (final r in allRecords) {
      byDate.putIfAbsent(r.dateKey, () => []).add(r);
    }
    final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحضور الكامل')),
      body: sortedDates.isEmpty
          ? const Center(child: Text('لم يتم تسجيل أي حضور بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final dateKey  = sortedDates[index];
                final records  = byDate[dateKey]!;
                final present  = records.where((r) => r.isPresent).length;
                final absent   = records.where((r) => !r.isPresent).length;
                final total    = present + absent;
                final pct      = total == 0 ? 0.0 : (present / total) * 100;

                // تجميع حسب النشاط
                final Map<String, List<AttendanceRecord>> byActivity = {};
                for (final r in records) {
                  byActivity.putIfAbsent(r.activity, () => []).add(r);
                }

                final date    = DateHelper.fromKey(dateKey);
                final dateStr = DateHelper.displayDateWithDay(date);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _pctColor(pct).withValues(alpha: 0.15),
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: _pctColor(pct),
                        ),
                      ),
                    ),
                    title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'حضر $present من $total • ${byActivity.keys.length} نشاط',
                      style: const TextStyle(fontSize: 12),
                    ),
                    children: byActivity.entries.map((entry) {
                      final activity      = entry.key;
                      final actRecords    = entry.value;
                      final actPresent    = actRecords.where((r) => r.isPresent).length;
                      final actTotal      = actRecords.length;
                      final presentNames  = actRecords
                          .where((r) => r.isPresent)
                          .map((r) {
                            final s = students.firstWhere(
                              (s) => s.id == r.studentId,
                              orElse: () => students.isEmpty
                                  ? throw Exception('no students')
                                  : students.first,
                            );
                            return s.fullName;
                          })
                          .toList();
                      final absentNames = actRecords
                          .where((r) => !r.isPresent)
                          .map((r) {
                            try {
                              final s = students.firstWhere((s) => s.id == r.studentId);
                              return s.fullName;
                            } catch (_) {
                              return 'غير معروف';
                            }
                          })
                          .toList();

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_note, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(activity,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(
                                    '$actPresent / $actTotal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _pctColor(actTotal == 0 ? 0 : actPresent / actTotal * 100),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (presentNames.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: AppColors.present),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'حضر: ${presentNames.join('، ')}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (absentNames.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.cancel, size: 14, color: AppColors.absent),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'غاب: ${absentNames.join('، ')}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.absent),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 75) return AppColors.present;
    if (pct >= 50) return AppColors.warning;
    return AppColors.absent;
  }
}
