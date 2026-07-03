import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/visit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/whatsapp_helper.dart';

/// صفحة الافتقاد الكاملة: تعرض كل الغائبين في آخر جلسة
/// مع خيار افتقاد فردي أو جماعي ورسالة واتساب
class PastoralScreen extends StatefulWidget {
  const PastoralScreen({super.key});

  @override
  State<PastoralScreen> createState() => _PastoralScreenState();
}

class _PastoralScreenState extends State<PastoralScreen> {
  final Set<String> _selected = {};
  bool _selectAll = false;

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final studentProvider    = context.watch<StudentProvider>();
    final visitProvider      = context.watch<VisitProvider>();
    final auth               = context.watch<AuthProvider>();
    final settings           = context.watch<SettingsProvider>();
    final allStudents        = studentProvider.allStudents;

    final absentStudents = attendanceProvider.getLastSessionAbsent(allStudents);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الافتقاد'),
        actions: [
          if (absentStudents.isNotEmpty)
            TextButton.icon(
              onPressed: () => _sendGroupWhatsapp(context, absentStudents, attendanceProvider, settings),
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: const Text('واتساب الجروب', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (absentStudents.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppColors.absent.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (v) {
                      setState(() {
                        _selectAll = v ?? false;
                        if (_selectAll) {
                          _selected.addAll(absentStudents.map((s) => s.id));
                        } else {
                          _selected.clear();
                        }
                      });
                    },
                  ),
                  const Text('تحديد الكل'),
                  const Spacer(),
                  if (_selected.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _bulkVisit(context, absentStudents, visitProvider, auth),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text('افتقاد ${_selected.length}'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                ],
              ),
            ),
          Expanded(
            child: absentStudents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 64, color: AppColors.present),
                        SizedBox(height: 12),
                        Text('ما فيش غايبين في آخر جلسة 🎉',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: absentStudents.length,
                    itemBuilder: (context, index) {
                      final student = absentStudents[index];
                      final visits  = visitProvider.getVisitsForStudent(student.id);
                      final lastVisit = visits.isNotEmpty ? visits.first : null;
                      final absDays   = attendanceProvider.absentDaysCount(student.id);
                      final lastAtt   = attendanceProvider.lastAttendance(student.id);
                      final isSelected = _selected.contains(student.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ExpansionTile(
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) _selected.add(student.id);
                                else _selected.remove(student.id);
                                _selectAll = _selected.length == absentStudents.length;
                              });
                            },
                          ),
                          title: Text(student.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('غاب $absDays مرة • '
                                  '${lastAtt != null ? 'آخر حضور: ${DateHelper.displayDate(DateHelper.fromKey(lastAtt.dateKey))}' : 'لم يحضر قط'}'),
                              if (lastVisit != null)
                                Text('آخر افتقاد: ${DateHelper.displayDate(DateHelper.fromKey(lastVisit.dateKey))}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _singleVisit(context, student.id, student.firstName, visitProvider, auth),
                                          icon: const Icon(Icons.search_off_rounded, size: 18),
                                          label: const Text('تسجيل افتقاد'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: student.phone.isNotEmpty
                                              ? () => _sendWhatsapp(context, student, settings)
                                              : null,
                                          icon: const Icon(Icons.send_rounded, size: 18),
                                          label: const Text('واتساب'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (visits.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Text('سجل الافتقاد السابق:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ...visits.take(3).map((v) => Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.circle, size: 6, color: AppColors.primary),
                                              const SizedBox(width: 6),
                                              Expanded(child: Text(v.note, style: const TextStyle(fontSize: 12))),
                                              Text(DateHelper.displayDate(DateHelper.fromKey(v.dateKey)),
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _singleVisit(BuildContext context, String studentId, String name,
      VisitProvider visitProvider, AuthProvider auth) async {
    final noteCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('افتقاد $name'),
        content: TextField(controller: noteCtrl, maxLines: 3,
            decoration: const InputDecoration(hintText: 'ملاحظة الافتقاد...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, noteCtrl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await visitProvider.addVisit(
          studentId: studentId, note: result, createdBy: auth.currentUser?.name ?? '');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تسجيل افتقاد $name')));
      }
    }
  }

  Future<void> _bulkVisit(BuildContext context, List<dynamic> absentStudents,
      VisitProvider visitProvider, AuthProvider auth) async {
    final noteCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('افتقاد جماعي (${_selected.length} شاب)'),
        content: TextField(controller: noteCtrl, maxLines: 3,
            decoration: const InputDecoration(hintText: 'ملاحظة موحدة للجميع...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, noteCtrl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final selectedIds = Set<String>.from(_selected);
    for (final id in selectedIds) {
      await visitProvider.addVisit(
          studentId: id, note: result, createdBy: auth.currentUser?.name ?? '');
    }
    setState(() { _selected.clear(); _selectAll = false; });
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم تسجيل الافتقاد لـ ${selectedIds.length} شاب')));
    }
  }

  Future<void> _sendWhatsapp(BuildContext context, dynamic student, SettingsProvider settings) async {
    final message = WhatsappHelper.buildMessage(settings.whatsappMessage, student.firstName);
    final opened  = await WhatsappHelper.openWhatsapp(phone: student.phone, message: message);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  /// رسالة الجروب: قائمة الغائبين مع نقاطهم
  Future<void> _sendGroupWhatsapp(BuildContext context, List<dynamic> absentStudents,
      AttendanceProvider attendanceProvider, SettingsProvider settings) async {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final buffer = StringBuffer();
    buffer.writeln('📋 سجل الغائبين - $dateStr');
    buffer.writeln('');
    for (int i = 0; i < absentStudents.length; i++) {
      final s = absentStudents[i];
      final pts = attendanceProvider.totalPoints(s.id);
      buffer.writeln('${i + 1}. ${s.firstName} — $pts نقطة');
    }
    buffer.writeln('');
    buffer.writeln('المجموع: ${absentStudents.length} غائب');

    final encoded  = Uri.encodeComponent(buffer.toString());
    final whatsUrl = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(whatsUrl)) {
      await launchUrl(whatsUrl, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }
}
