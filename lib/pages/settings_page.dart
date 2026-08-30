import 'package:flutter/cupertino.dart';
import '../data/db.dart';
import '../data/export.dart';
import '../models/models.dart';
import '../widgets/ios_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _rateCtrl;
  List<ShiftRule> _shifts = [];
  List<ModelLibItem> _models = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _rateCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await AppDb.getSettings();
    final shifts = await AppDb.getShiftRules();
    final models = await AppDb.getModelLib();
    if (!mounted) return;
    setState(() {
      _rateCtrl.text = s.ratePerSecond.toStringAsFixed(4);
      _shifts = shifts;
      _models = models;
      _loading = false;
    });
  }

  Future<void> _saveRate() async {
    final v = double.tryParse(_rateCtrl.text);
    if (v == null || v <= 0) {
      _snack('秒单价格式不对');
      return;
    }
    final s = await AppDb.getSettings();
    await AppDb.saveSettings(AppSettings(ratePerSecond: v, defaultMode: s.defaultMode));
    _snack('已保存秒单价');
  }

  void _snack(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('好的'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('设置'),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const IosSectionHeader('工资设置'),
                  IosGroup(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('秒单价（元/秒）',
                              style: TextStyle(fontSize: 16, color: kIosLabel)),
                        ),
                        SizedBox(
                          width: 120,
                          child: CupertinoTextField(
                            controller: _rateCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _saveRate,
                          child: const Text('保存',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: kIosBlue)),
                        ),
                      ],
                    ),
                  ),
                  const IosSectionHeader('班次规则'),
                  CupertinoListSection.insetGrouped(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    children: [
                      ..._shifts.map((s) => CupertinoListTile(
                            title: Text('${s.name}  ×${s.multiplier}',
                                style: const TextStyle(fontSize: 16)),
                            subtitle: Text('默认补助 ${s.defaultSubsidy.toStringAsFixed(0)} 元/班（记单时可改）',
                                style: const TextStyle(fontSize: 12, color: kIosSecondary)),
                            trailing: const Icon(CupertinoIcons.chevron_right,
                                size: 16, color: kIosSecondary),
                            onTap: () => _editShift(s),
                          )),
                      CupertinoListTile(
                        title: const Text('新增班次',
                            style: TextStyle(fontSize: 16, color: kIosBlue)),
                        leading: const Icon(CupertinoIcons.add, color: kIosBlue),
                        onTap: () => _editShift(null),
                      ),
                    ],
                  ),
                  const IosSectionHeader('常用件型库'),
                  CupertinoListSection.insetGrouped(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    children: [
                      ..._models.map((m) => CupertinoListTile(
                            title: Text(m.name,
                                style: const TextStyle(fontSize: 16)),
                            subtitle: Text(m.desc,
                                style: const TextStyle(fontSize: 12, color: kIosSecondary)),
                            trailing: const Icon(CupertinoIcons.chevron_right,
                                size: 16, color: kIosSecondary),
                            onTap: () => _editModel(m),
                          )),
                      if (_models.isEmpty)
                        const CupertinoListTile(
                          title: Text('还没有常用件型，点下面新增',
                              style: TextStyle(fontSize: 14, color: kIosSecondary)),
                        ),
                      CupertinoListTile(
                        title: const Text('新增件型',
                            style: TextStyle(fontSize: 16, color: kIosBlue)),
                        leading: const Icon(CupertinoIcons.add, color: kIosBlue),
                        onTap: () => _editModel(null),
                      ),
                    ],
                  ),
                  const IosSectionHeader('数据'),
                  CupertinoListSection.insetGrouped(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    children: [
                      CupertinoListTile(
                        leading: const Icon(CupertinoIcons.doc_on_doc,
                            color: kIosBlue),
                        title: const Text('生成 Excel 报表',
                            style: TextStyle(fontSize: 16)),
                        trailing: const Icon(CupertinoIcons.chevron_right,
                            size: 16, color: kIosSecondary),
                        onTap: () async {
                          final path = await exportExcel();
                          _snack(path == null ? '导出失败' : '已生成报表');
                        },
                      ),
                      CupertinoListTile(
                        leading: const Icon(CupertinoIcons.share, color: kIosBlue),
                        title: const Text('导出并分享',
                            style: TextStyle(fontSize: 16)),
                        trailing: const Icon(CupertinoIcons.chevron_right,
                            size: 16, color: kIosSecondary),
                        onTap: () async {
                          final path = await exportExcel();
                          if (path != null) await shareReport(path);
                        },
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text('秒薪计件 v1.0.0 · 免费本地版\n数据保存在手机本地，无账号无云端。',
                        style: TextStyle(fontSize: 12, color: kIosSecondary)),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _editShift(ShiftRule? rule) async {
    final nameCtrl = TextEditingController(text: rule?.name ?? '');
    final mulCtrl = TextEditingController(text: (rule?.multiplier ?? 1.0).toString());
    final subCtrl = TextEditingController(text: (rule?.defaultSubsidy ?? 0).toStringAsFixed(0));
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(rule == null ? '新增班次' : '编辑班次'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(controller: nameCtrl, placeholder: '班次名（如 夜班）'),
            const SizedBox(height: 8),
            CupertinoTextField(
                controller: mulCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: '倍率（如 1.2）'),
            const SizedBox(height: 8),
            CupertinoTextField(
                controller: subCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: '默认补助（元/班）'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('保存'),
            onPressed: () async {
              Navigator.pop(ctx);
              final mul = double.tryParse(mulCtrl.text) ?? 1.0;
              final sub = double.tryParse(subCtrl.text) ?? 0;
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              if (rule == null) {
                await AppDb.insertShiftRule(
                    ShiftRule(name: name, multiplier: mul, defaultSubsidy: sub));
              } else {
                await AppDb.updateShiftRule(ShiftRule(
                    id: rule.id, name: name, multiplier: mul, defaultSubsidy: sub));
              }
              _load();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editModel(ModelLibItem? item) async {
    PayMode mode = item == null ? PayMode.perSecond : payModeFromName(item.mode);
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final paramCtrl = TextEditingController(
        text: item == null
            ? ''
            : mode == PayMode.perSecond
                ? (item.unitSeconds?.round().toString() ?? '')
                : mode == PayMode.perPiece
                    ? (item.unitPrice?.toString() ?? '')
                    : (item.hourlyRate?.toString() ?? ''));
    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => CupertinoAlertDialog(
        title: Text(item == null ? '新增件型' : '编辑件型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(controller: nameCtrl, placeholder: '名称（如 A型）'),
            const SizedBox(height: 10),
            CupertinoSlidingSegmentedControl<PayMode>(
              groupValue: mode,
              children: {
                PayMode.perSecond: const Text('按秒'),
                PayMode.perPiece: const Text('按件'),
                PayMode.perHour: const Text('按小时'),
              },
              onValueChanged: (m) => setDlg(() => mode = m ?? PayMode.perSecond),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: paramCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              placeholder: mode == PayMode.perSecond
                  ? '单件耗时（秒）'
                  : mode == PayMode.perPiece
                      ? '单价（元/件）'
                      : '时薪（元/小时）',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('保存'),
            onPressed: () async {
              Navigator.pop(ctx);
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final pv = double.tryParse(paramCtrl.text) ?? 0;
              final m = ModelLibItem(
                id: item?.id,
                name: name,
                mode: payModeName(mode),
                unitSeconds: mode == PayMode.perSecond ? pv : null,
                unitPrice: mode == PayMode.perPiece ? pv : null,
                hourlyRate: mode == PayMode.perHour ? pv : null,
              );
              if (item == null) {
                await AppDb.insertModelLib(m);
              } else {
                await AppDb.updateModelLib(m);
              }
              _load();
            },
          ),
        ],
      )),
    );
  }
}
