import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../widgets/care_form_theme.dart';

class MedicineCreatePage extends ConsumerStatefulWidget {
  const MedicineCreatePage({super.key, required this.targetUserId});

  final int targetUserId;

  @override
  ConsumerState<MedicineCreatePage> createState() => _MedicineCreatePageState();
}

class _MedicineCreatePageState extends ConsumerState<MedicineCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _dosageForm = 'tablet';
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _composeNote() {
    final user = _noteCtrl.text.trim();
    final formEntry = kDosageForms.firstWhere((e) => e.value == _dosageForm, orElse: () => kDosageForms.first);
    if (_dosageForm == 'tablet') {
      return user.isEmpty ? '' : user;
    }
    final prefix = '剂型：${formEntry.label}';
    if (user.isEmpty) return prefix;
    return '$prefix\n$user';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(careRepositoryProvider);
      final noteRaw = _composeNote().trim();
      await repo.createMedicine(
        targetUserId: widget.targetUserId,
        name: _nameCtrl.text,
        specification: _specCtrl.text,
        note: noteRaw.isEmpty ? null : noteRaw,
      );
      if (!mounted) return;
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareFormTheme.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: CareFormTheme.scaffoldBg,
        foregroundColor: CareFormTheme.slate700,
        title: const Text('添加药品', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Form(
          key: _formKey,
          child: DecoratedBox(
            decoration: CareFormTheme.card(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFDDBE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.medication_liquid_rounded, size: 18, color: CareFormTheme.blue600),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '药品会记入当前管理对象名下，后续可直接用于创建计划。',
                            style: CareFormTheme.hintSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('药品名称', style: CareFormTheme.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: CareFormTheme.fieldDecoration(hint: '例如：氨氯地平'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('规格', style: CareFormTheme.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _specCtrl,
                    decoration: CareFormTheme.fieldDecoration(hint: '例如：5mg * 30片'),
                  ),
                  const SizedBox(height: 16),
                  const Text('剂型', style: CareFormTheme.label),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, c) {
                      const spacing = 8.0;
                      final w = (c.maxWidth - spacing * 2) / 3;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final f in kDosageForms)
                            SizedBox(
                              width: w,
                              child: CareFormTheme.frequencyChip(
                                label: f.label,
                                selected: _dosageForm == f.value,
                                onTap: () => setState(() => _dosageForm = f.value),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('备注 (可选)', style: CareFormTheme.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: CareFormTheme.fieldDecoration(hint: '例如：饭后服用', maxLines: 3),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: CareFormTheme.primaryButton(enabled: !_busy),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('正在保存...'),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('保存药品'),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
