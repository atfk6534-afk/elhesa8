import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student_model.dart';
import '../../providers/student_provider.dart';
import '../../core/utils/name_helper.dart';

class AddEditStudentScreen extends StatefulWidget {
  final StudentModel? student;
  const AddEditStudentScreen({super.key, this.student});
  bool get isEditing => student != null;

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _phone2Ctrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _addressDetailCtrl;
  late final TextEditingController _birthDateCtrl;
  late final TextEditingController _notesCtrl;
  bool _firstNameEdited = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _fullNameCtrl    = TextEditingController(text: s?.fullName ?? '');
    _firstNameCtrl   = TextEditingController(text: s?.firstName ?? '');
    _phoneCtrl       = TextEditingController(text: s?.phone ?? '');
    _phone2Ctrl      = TextEditingController(text: s?.phone2 ?? '');
    _addressCtrl     = TextEditingController(text: s?.address ?? '');
    _addressDetailCtrl = TextEditingController(text: s?.addressDetail ?? '');
    _birthDateCtrl   = TextEditingController(text: s?.birthDate ?? '');
    _notesCtrl       = TextEditingController(text: s?.notes ?? '');
    _firstNameEdited = widget.isEditing;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose(); _firstNameCtrl.dispose();
    _phoneCtrl.dispose(); _phone2Ctrl.dispose();
    _addressCtrl.dispose(); _addressDetailCtrl.dispose();
    _birthDateCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  void _onFullNameChanged(String value) {
    if (!_firstNameEdited) _firstNameCtrl.text = NameHelper.extractFirstName(value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = context.read<StudentProvider>();
    if (widget.isEditing) {
      await provider.updateStudent(widget.student!.copyWith(
        fullName: _fullNameCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        phone2: _phone2Ctrl.text.trim(),
        address: _addressCtrl.text.trim(),
        addressDetail: _addressDetailCtrl.text.trim(),
        birthDate: _birthDateCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ));
    } else {
      await provider.addStudent(
        fullName: _fullNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        phone2: _phone2Ctrl.text.trim(),
        address: _addressCtrl.text.trim(),
        addressDetail: _addressDetailCtrl.text.trim(),
        birthDate: _birthDateCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        customFirstName: _firstNameCtrl.text.trim(),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3D5A80))),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'تعديل بيانات شاب' : 'إضافة شاب جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header('الاسم'),
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الثلاثي *'),
                  onChanged: _onFullNameChanged,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الأول (للمخاطبة)'),
                  onChanged: (_) => _firstNameEdited = true,
                ),
                _header('أرقام التليفون'),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'رقم تليفون أول (واتساب) *', prefixIcon: Icon(Icons.phone_android)),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone2Ctrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'رقم تليفون تاني (اختياري)', prefixIcon: Icon(Icons.phone)),
                ),
                _header('العنوان وتاريخ الميلاد'),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان', prefixIcon: Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressDetailCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'العنوان التفصيلي (اختياري)', prefixIcon: Icon(Icons.signpost_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthDateCtrl,
                  keyboardType: TextInputType.datetime,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'تاريخ الميلاد (مثال: 01/01/2005)', prefixIcon: Icon(Icons.cake_outlined)),
                ),
                _header('ملاحظات'),
                TextFormField(controller: _notesCtrl, maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(widget.isEditing ? 'حفظ التعديلات' : 'إضافة الشاب'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
