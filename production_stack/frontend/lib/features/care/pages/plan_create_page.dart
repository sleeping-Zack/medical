import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../models/medicine_item.dart';
import '../providers/care_remote_providers.dart';
import '../widgets/care_form_theme.dart';

class _ScheduleSlot {
  _ScheduleSlot(this.hour, this.minute);

  int hour;
  int minute;
}

class PlanCreatePage extends ConsumerStatefulWidget {
  const PlanCreatePage({super.key, required this.targetUserId});

  final int targetUserId;

  @override
  ConsumerState<PlanCreatePage> createState() => _PlanCreatePageState();
}

class _PlanCreatePageState extends ConsumerState<PlanCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();

  DateTime _start = DateTime.now();
  int? _medicineId;
  List<MedicineItem> _meds = [];
  bool _loadingMeds = true;
  bool _busy = false;
  String? _loadErr;

  /// 与 Web 一致：可与日程条数不同步（超过 4 次则无高亮）
  int _frequency = 1;
  final List<_ScheduleSlot> _schedules = [_ScheduleSlot(8, 0)];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  static const List<List<int>> _presetStarts = [
    [8, 0],
    [12, 0],
    [18, 0],
    [22, 0],
  ];

  void _applyFrequencyPreset(int freq) {
    setState(() {
      _frequency = freq;
      _schedules.clear();
      for (var i = 0; i < freq; i++) {
        if (i < _presetStarts.length) {
          _schedules.add(_ScheduleSlot(_presetStarts[i][0], _presetStarts[i][1]));
        } else {
          _schedules.add(_ScheduleSlot(8 + i * 4, 0));
        }
      }
    });
  }

  void _addSchedule() {
    setState(() {
      _schedules.add(_ScheduleSlot(12, 0));
      _frequency = _schedules.length;
    });
  }

  void _removeSchedule(int index) {
    if (_schedules.length <= 1) return;
    setState(() {
      _schedules.removeAt(index);
      _frequency = _schedules.length;
    });
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

  String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtHm(_ScheduleSlot s) =>
      '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(_start.year - 1),
      lastDate: DateTime(_start.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: CareFormTheme.blue600, surface: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _openTimeEditor(int index) async {
    final slot = _schedules[index];
    var h = slot.hour;
    var m = slot.minute;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('设定服药时间', style: CareFormTheme.label.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('请选择小时和分钟', style: CareFormTheme.hintSmall),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: CareFormTheme.slate50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: CareFormTheme.blue100, width: 2),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: h,
                                icon: const SizedBox.shrink(),
                                alignment: Alignment.center,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CareFormTheme.blue600),
                                items: List.generate(
                                  24,
                                  (i) => DropdownMenuItem(value: i, child: Center(child: Text(i.toString().padLeft(2, '0')))),
                                ),
                                onChanged: (v) {
                                  if (v != null) setModal(() => h = v);
                                },
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CareFormTheme.slate500)),
                        ),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: CareFormTheme.slate50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: CareFormTheme.blue100, width: 2),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: m,
                                icon: const SizedBox.shrink(),
                                alignment: Alignment.center,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CareFormTheme.blue600),
                                items: List.generate(
                                  60,
                                  (i) => DropdownMenuItem(value: i, child: Center(child: Text(i.toString().padLeft(2, '0')))),
                                ),
                                onChanged: (v) {
                                  if (v != null) setModal(() => m = v);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: CareFormTheme.primaryButton(enabled: true),
                      onPressed: () {
                        setState(() {
                          _schedules[index].hour = h;
                          _schedules[index].minute = m;
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('确认时间'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _schedulesToApi() {
    return _schedules
        .map((s) => {'hour': s.hour, 'minute': s.minute, 'weekdays': '1111111'})
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medicineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先添加药品')));
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(careRepositoryProvider);
      await repo.createPlan(
        targetUserId: widget.targetUserId,
        medicineId: _medicineId!,
        startDateIso: _isoDate(_start),
        schedules: _schedulesToApi(),
        label: _labelCtrl.text,
      );
      ref.invalidate(plansForTargetProvider(widget.targetUserId));
      ref.invalidate(remindersForTargetTodayProvider(widget.targetUserId));
      if (!mounted) return;
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration get _medicineDropdownDecoration {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CareFormTheme.slate200)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CareFormTheme.slate200)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CareFormTheme.blue600, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMeds) {
      return Scaffold(
        backgroundColor: CareFormTheme.scaffoldBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: CareFormTheme.scaffoldBg,
          foregroundColor: CareFormTheme.slate700,
          title: const Text('新建用药计划', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadErr != null) {
      return Scaffold(
        backgroundColor: CareFormTheme.scaffoldBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: CareFormTheme.scaffoldBg,
          foregroundColor: CareFormTheme.slate700,
          title: const Text('新建用药计划', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: CareFormTheme.card(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadErr!, textAlign: TextAlign.center, style: const TextStyle(color: CareFormTheme.slate700)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: CareFormTheme.primaryButton(enabled: true),
                      onPressed: _loadMedicines,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_meds.isEmpty) {
      return Scaffold(
        backgroundColor: CareFormTheme.scaffoldBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: CareFormTheme.scaffoldBg,
          foregroundColor: CareFormTheme.slate700,
          title: const Text('新建用药计划', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: DecoratedBox(
              decoration: CareFormTheme.card(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CareFormTheme.amber50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CareFormTheme.amber100),
                      ),
                      child: Text(
                        '该对象还没有药品，请先在「药品」页为其添加药品后再建计划。',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: CareFormTheme.amber700.withValues(alpha: 0.95)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      style: CareFormTheme.primaryButton(enabled: true),
                      onPressed: () => context.pushReplacement('/care/medicines/new?target=${widget.targetUserId}'),
                      child: const Text('去添加药品'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CareFormTheme.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: CareFormTheme.scaffoldBg,
        foregroundColor: CareFormTheme.slate700,
        title: const Text('新建用药计划', style: TextStyle(fontWeight: FontWeight.w800)),
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
                        Icon(Icons.calendar_month_rounded, size: 18, color: CareFormTheme.blue600),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '按药品 + 频率 + 时间建立日程，和 web 端保持一致。',
                            style: CareFormTheme.hintSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('选择药品', style: CareFormTheme.label),
                  const SizedBox(height: 6),
                  // Controlled field：仍用 value 与列表同步（SDK 提示的 initialValue 不适合每次 setState 更新）
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _medicineId,
                    decoration: _medicineDropdownDecoration,
                    items: _meds
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m.id,
                            child: Text(m.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _busy ? null : (v) => setState(() => _medicineId = v),
                    validator: (v) => v == null ? '请选择药品' : null,
                  ),
                  const SizedBox(height: 18),
                  const Text('开始日期', style: CareFormTheme.label),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _busy ? null : _pickStartDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CareFormTheme.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CareFormTheme.slate200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CareFormTheme.blue600, width: 2),
                          ),
                          suffixIcon:
                              const Icon(Icons.calendar_today_outlined, size: 18, color: CareFormTheme.slate500),
                        ),
                        child: Text(
                          _isoDate(_start),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CareFormTheme.slate900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('用药频率', style: CareFormTheme.label),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var f = 1; f <= 4; f++) ...[
                        if (f > 1) const SizedBox(width: 8),
                        Expanded(
                          child: CareFormTheme.frequencyChip(
                            label: '每日$f次',
                            selected: _frequency == f && _schedules.length == f,
                            onTap: () {
                              if (!_busy) _applyFrequencyPreset(f);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text('用药时间', style: CareFormTheme.label),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _busy ? null : _addSchedule,
                        icon: const Icon(Icons.add_rounded, size: 18, color: CareFormTheme.blue600),
                        label: const Text('添加时间', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: CareFormTheme.blue600, padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var idx = 0; idx < _schedules.length; idx++) ...[
                    if (idx > 0) const SizedBox(height: 10),
                    _scheduleCard(idx),
                  ],
                  const SizedBox(height: 16),
                  const Text('计划备注（可选）', style: CareFormTheme.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _labelCtrl,
                    enabled: !_busy,
                    decoration: CareFormTheme.fieldDecoration(hint: '便于自己区分多个计划'),
                  ),
                  const SizedBox(height: 22),
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
                              const Text('正在创建...'),
                            ],
                          )
                        : const Text('创建计划'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduleCard(int idx) {
    final s = _schedules[idx];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CareFormTheme.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CareFormTheme.slate100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _busy ? null : () => _openTimeEditor(idx),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 20, color: CareFormTheme.blue600),
                      const SizedBox(width: 8),
                      Text(
                        _fmtHm(s),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CareFormTheme.slate900),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_schedules.length > 1)
            IconButton(
              onPressed: _busy ? null : () => _removeSchedule(idx),
              style: IconButton.styleFrom(foregroundColor: Colors.red.shade400),
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
            ),
        ],
      ),
    );
  }
}
