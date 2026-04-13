import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../models/medicine_item.dart';

class PlanCreatePage extends ConsumerStatefulWidget {
  const PlanCreatePage({super.key, required this.targetUserId});

  final int targetUserId;

  @override
  ConsumerState<PlanCreatePage> createState() => _PlanCreatePageState();
}

class _PlanCreatePageState extends ConsumerState<PlanCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _timesCtrl = TextEditingController(text: '08:00,20:00');
  final _labelCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  int? _medicineId;
  List<MedicineItem> _meds = [];
  bool _loadingMeds = true;
  bool _busy = false;
  String? _loadErr;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _timesCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    setState(() {
      _loadingMeds = true;
      _loadErr = null;
    });
    try {
      final repo = ref.read(careRepositoryProvider);
      final list = await repo.listMedicines(targetUserId: widget.targetUserId);
      if (!mounted) return;
      setState(() {
        _meds = list;
        _medicineId = list.isNotEmpty ? list.first.id : null;
        _loadingMeds = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadErr = e.message;
        _loadingMeds = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadErr = '加载药品失败';
        _loadingMeds = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseSchedules(String raw) {
    final result = <Map<String, dynamic>>[];
    for (final part in raw.split(',')) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final hm = p.split(':');
      if (hm.length != 2) {
        throw FormatException('时间须为 HH:mm，多个用英文逗号分隔');
      }
      final h = int.tryParse(hm[0].trim());
      final m = int.tryParse(hm[1].trim());
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        throw FormatException('时间范围无效');
      }
      result.add({'hour': h, 'minute': m, 'weekdays': '1111111'});
    }
    if (result.isEmpty) {
      throw FormatException('请至少填写一个提醒时间');
    }
    return result;
  }

  String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(_start.year - 1),
      lastDate: DateTime(_start.year + 5),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medicineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先添加药品')));
      return;
    }
    List<Map<String, dynamic>> schedules;
    try {
      schedules = _parseSchedules(_timesCtrl.text);
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(careRepositoryProvider);
      await repo.createPlan(
        targetUserId: widget.targetUserId,
        medicineId: _medicineId!,
        startDateIso: _isoDate(_start),
        schedules: schedules,
        label: _labelCtrl.text,
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
    if (_loadingMeds) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadErr != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('新建计划')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadErr!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadMedicines, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }
    if (_meds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('新建计划')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('该长辈暂无药品，请先添加药品。'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.pushReplacement('/care/medicines/new?target=${widget.targetUserId}'),
                  child: const Text('去添加药品'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('新建服药计划')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                value: _medicineId,
                decoration: const InputDecoration(labelText: '关联药品', border: OutlineInputBorder()),
                items: _meds
                    .map(
                      (m) => DropdownMenuItem<int>(
                        value: m.id,
                        child: Text(m.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _medicineId = v),
                validator: (v) => v == null ? '请选择药品' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开始日期'),
                subtitle: Text(_isoDate(_start)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _timesCtrl,
                decoration: const InputDecoration(
                  labelText: '每日提醒时间',
                  helperText: '格式 HH:mm，多个用英文逗号分隔；默认周一至周日均提醒',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请填写时间' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(labelText: '计划备注（可选）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('保存计划'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
