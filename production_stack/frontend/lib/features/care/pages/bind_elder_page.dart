import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

class BindElderPage extends ConsumerStatefulWidget {
  const BindElderPage({super.key});

  @override
  ConsumerState<BindElderPage> createState() => _BindElderPageState();
}

class _BindElderPageState extends ConsumerState<BindElderPage> {
  final _formKey = GlobalKey<FormState>();
  final _shortIdCtrl = TextEditingController();
  final _last4Ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _shortIdCtrl.dispose();
    _last4Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(careRepositoryProvider);
      await repo.createBinding(
        elderShortId: _shortIdCtrl.text.trim(),
        phoneLast4: _last4Ctrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('绑定成功')));
      context.pop();
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
      appBar: AppBar(title: const Text('绑定长辈账号')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '请让长辈在「设置 / 首页」查看 6 位绑定短号，并确认其注册手机号后四位。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _shortIdCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '长辈绑定短号（6 位数字）',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.length != 6 || int.tryParse(s) == null) return '请输入 6 位数字';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _last4Ctrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: '长辈手机号后四位',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.length != 4 || int.tryParse(s) == null) return '请输入后四位数字';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('确认绑定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
