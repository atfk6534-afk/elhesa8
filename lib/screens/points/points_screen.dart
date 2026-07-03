import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';

/// صفحة عرض نقاط كل الشباب + خصم/إضافة نقاط يدوي + رسالة جروب بالنقاط
class PointsScreen extends StatelessWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final students  = context.watch<StudentProvider>().allStudents;
    final attendPro = context.watch<AttendanceProvider>();

    // ترتيب تنازلي حسب النقاط
    final sorted = [...students];
    sorted.sort((a, b) => attendPro.totalPoints(b.id).compareTo(attendPro.totalPoints(a.id)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('النقاط'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded),
            tooltip: 'رسالة النقاط للجروب',
            onPressed: () => _sendGroupPoints(context, sorted, attendPro),
          ),
        ],
      ),
      body: students.isEmpty
          ? const Center(child: Text('لا يوجد شباب بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final student = sorted[index];
                final total  = attendPro.totalPoints(student.id);
                final attPts = attendPro.attendancePoints(student.id);
                final adjPts = attendPro.adjustmentPoints(student.id);
                final adjs   = attendPro.getAdjustmentsForStudent(student.id);

                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _rankColor(index).withValues(alpha: 0.15),
                      child: Text('${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _rankColor(index))),
                    ),
                    title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('إجمالي: $total نقطة'
                        '${adjPts != 0 ? ' (حضور: $attPts + تعديل: ${adjPts > 0 ? '+' : ''}$adjPts)' : ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.present),
                          tooltip: 'إضافة نقاط',
                          onPressed: () => _adjustPoints(context, student.id, student.firstName, true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: AppColors.absent),
                          tooltip: 'خصم نقاط',
                          onPressed: () => _adjustPoints(context, student.id, student.firstName, false),
                        ),
                      ],
                    ),
                    children: [
                      if (adjs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('سجل التعديلات اليدوية:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              ...adjs.map((a) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(a.delta >= 0 ? Icons.add_circle : Icons.remove_circle,
                                            size: 14,
                                            color: a.delta >= 0 ? AppColors.present : AppColors.absent),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text('${a.delta >= 0 ? '+' : ''}${a.delta} نقطة'
                                              '${a.reason.isNotEmpty ? ' • ${a.reason}' : ''}',
                                              style: const TextStyle(fontSize: 12)),
                                        ),
                                        Text(DateHelper.displayDate(DateHelper.fromKey(a.dateKey)),
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _rankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // ذهبي
    if (index == 1) return const Color(0xFFC0C0C0); // فضي
    if (index == 2) return const Color(0xFFCD7F32); // برونزي
    return AppColors.primary;
  }

  Future<void> _adjustPoints(BuildContext context, String studentId, String name, bool isAdd) async {
    final amountCtrl = TextEditingController(text: '5');
    final reasonCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isAdd ? 'إضافة' : 'خصم'} نقاط - $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'عدد النقاط', prefixText: isAdd ? '+' : '-'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'السبب (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isAdd ? AppColors.present : AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAdd ? 'إضافة' : 'خصم', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    final delta = isAdd ? amount : -amount;
    final auth  = context.read<AuthProvider>();
    await context.read<AttendanceProvider>().addPointAdjustment(
          studentId: studentId,
          delta: delta,
          reason: reasonCtrl.text.trim(),
          createdBy: auth.currentUser?.name ?? '',
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isAdd ? 'أضفت' : 'خصمت'} $amount نقطة ${isAdd ? 'لـ' : 'من'} $name')));
    }
  }

  Future<void> _sendGroupPoints(BuildContext context, List<dynamic> students,
      AttendanceProvider attendPro) async {
    final now     = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final buffer  = StringBuffer();
    buffer.writeln('🏆 قائمة النقاط - $dateStr');
    buffer.writeln('');
    for (int i = 0; i < students.length; i++) {
      final s   = students[i];
      final pts = attendPro.totalPoints(s.id);
      final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}.';
      buffer.writeln('$medal ${s.firstName} — $pts نقطة');
    }

    final encoded  = Uri.encodeComponent(buffer.toString());
    final whatsUrl = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(whatsUrl)) {
      await launchUrl(whatsUrl, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }
}
