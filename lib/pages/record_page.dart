import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../data/db.dart';
import '../data/calc.dart';
import '../models/models.dart';
import '../widgets/ios_ui.dart';

class RecordPage extends StatefulWidget {
  final WorkOrder? editOrder;
  final List<WorkOrderLine>? editLines;
  const RecordPage({super.key, this.editOrder, this.editLines});
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _LineEdit {
  String model = '';
  PayMode mode = PayMode.perSecond;
  String durationText = '';
  String priceText = '';
  String hourlyText = '';
  String hoursText = '';
  String dayRateText = '';
  String daysText = '';
  String qtyText = '';
  _LineEdit();
  _LineEdit.fromLine(WorkOrderLine l) {
    model = l.model;
    mode = payModeFromName(l.mode);
    if (mode == PayMode.perSecond) {
      durationText = l.unitSeconds?.round().toString() ?? '';
    } else if (mode == PayMode.perPiece) {
      priceText = l.unitPrice?.toString() ?? '';
    } else if (mode == PayMode.perHour) {
      hourlyText = l.hourlyRate?.toString() ?? '';
      hoursText = l.hours?.toString() ?? '';
    } else {
      dayRateText = l.dayRate?.toString() ?? '';
      daysText = l.days?.toString() ?? '';
    }
    qtyText = l.quantity.toString();
  }
}

class _RecordPageState extends State<RecordPage> {
  late DateTime _date;
  late TextEditingController _machineCtrl;
  late TextEditingController _subsidyCtrl;
  List<String> _machines = [];
  List<ShiftRule> _shifts = [];
  ShiftRule? _shift;
  AppSettings _settings = AppSettings();
  double _subsidy = 0;
  final List<_LineEdit> _lines = [];

  bool get _isEdit => widget.editOrder != null;

  @override
  void initState() {
    super.initState();
    _date = _isEdit ? DateTime.parse(widget.editOrder!.date) : DateTime.now();
    _machineCtrl = TextEditingController(text: widget.editOrder?.machine ?? '');
    _subsidyCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _machineCtrl.dispose();
    _subsidyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await AppDb.getSettings();
    final shifts = await AppDb.getShiftRules();
    final machines = await AppDb.distinctMachines();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _shifts = shifts;
      _machines = machines;
      if (_isEdit) {
        _shift = null;
        for (final s in shifts) {
          if (s.id == widget.editOrder!.shiftRuleId) _shift = s;
        }
        _subsidy = widget.editOrder!.subsidy;
        _subsidyCtrl.text = _subsidy > 0 ? _subsidy.toString() : '';
        _lines
          ..clear()
          ..addAll((widget.editLines ?? []).map((l) => _LineEdit.fromLine(l)));
      } else {
        _shift = _shifts.isNotEmpty ? _shifts.first : null;
        _subsidy = 0;
        _subsidyCtrl.text = '';
        if (_lines.isEmpty) _lines.add(_LineEdit());
      }
    });
  }

  WorkOrderLine? _toLine(_LineEdit e) {
    final qty = double.tryParse(e.qtyText) ?? 0;
    if (e.model.trim().isEmpty || qty <= 0) return null;
    if (e.mode == PayMode.perSecond) {
      final sec = parseDurationSeconds(e.durationText);
      if (sec == null || sec <= 0) return null;
      return WorkOrderLine(
          model: e.model.trim(),
          mode: payModeName(e.mode),
          unitSeconds: sec.toDouble(),
          quantity: qty,
          lineTotal: _settings.ratePerSecond * sec * qty);
    } else if (e.mode == PayMode.perPiece) {
      final price = double.tryParse(e.priceText) ?? 0;
      if (price <= 0) return null;
      return WorkOrderLine(
          model: e.model.trim(),
          mode: payModeName(e.mode),
          unitPrice: price,
          quantity: qty,
          lineTotal: price * qty);
    } else if (e.mode == PayMode.perHour) {
      final rate = double.tryParse(e.hourlyText) ?? 0;
      final hours = double.tryParse(e.hoursText) ?? 0;
      if (rate <= 0 || hours <= 0) return null;
      return WorkOrderLine(
          model: e.model.trim(),
          mode: payModeName(e.mode),
          hourlyRate: rate,
          hours: hours,
          quantity: 0,
          lineTotal: rate * hours);
    } else {
      final dayRate = double.tryParse(e.dayRateText) ?? 0;
      final days = double.tryParse(e.daysText) ?? 0;
      if (dayRate <= 0 || days <= 0) return null;
      return WorkOrderLine(
          model: e.model.trim(),
          mode: payModeName(e.mode),
          dayRate: dayRate,
          days: days,
          quantity: 0,
          lineTotal: dayRate * days);
    }
  }

  ({double base, double total}) get _preview {
    if (_shift == null) return (base: 0, total: 0);
    final lines = <WorkOrderLine>[];
    for (final e in _lines) {
      final l = _toLine(e);
      if (l != null) lines.add(l);
    }
    return calcOrderTotal(lines, _subsidy, _settings.ratePerSecond);
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

  Future<void> _save() async {
    final machine = _machineCtrl.text.trim();
    if (machine.isEmpty) {
      _snack('请填写机器/工位名称');
      return;
    }
    if (_shift == null) {
      _snack('请选择班次');
      return;
    }
    final lines = <WorkOrderLine>[];
    for (final e in _lines) {
      final l = _toLine(e);
      if (l != null) lines.add(l);
    }
    if (lines.isEmpty) {
      _snack('请至少填写一行有效明细（件型、耗时/单价、件数）');
      return;
    }
    final p = calcOrderTotal(lines, _subsidy, _settings.ratePerSecond);
    final order = WorkOrder(
      id: widget.editOrder?.id,
      date: DateFormat('yyyy-MM-dd').format(_date),
      machine: machine,
      shiftRuleId: _shift!.id!,
      subsidy: _subsidy,
      baseTotal: p.base,
      totalAmount: p.total,
      createdAt: widget.editOrder?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    if (_isEdit) {
      await AppDb.updateOrder(order, lines);
    } else {
      await AppDb.insertOrder(order, lines);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: CupertinoColors.white,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _date,
          minimumDate: DateTime(2020),
          maximumDate: DateTime.now().add(const Duration(days: 365)),
          onDateTimeChanged: (d) => setState(() => _date = d),
        ),
      ),
    );
  }

  void _selectShift(ShiftRule s) {
    setState(() {
      _shift = s;
      // 补助不自动带出，让工人自己填（每个人不一样）
    });
  }

  void _selectSubsidy(double v) {
    setState(() {
      _subsidy = v;
      _subsidyCtrl.text = v > 0 ? v.toString() : '';
    });
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      borderRadius: BorderRadius.circular(9),
      color: selected ? kIosBlue : const Color(0xFFEAF2FF),
      pressedOpacity: 0.7,
      onPressed: onTap,
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? CupertinoColors.white : kIosBlue)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEdit ? '编辑计件单' : '记一笔'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('保存',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kIosBlue)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _basicGroup(),
                  const IosSectionHeader('明细（一单可多种件）'),
                  for (var i = 0; i < _lines.length; i++) _lineCard(i, _lines[i]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: CupertinoButton(
                      borderRadius: BorderRadius.circular(12),
                      color: CupertinoColors.white,
                      pressedOpacity: 0.7,
                      onPressed: () => setState(() => _lines.add(_LineEdit())),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.plus_circle, color: kIosBlue),
                          SizedBox(width: 6),
                          Text('添加明细行', style: TextStyle(color: kIosBlue, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _previewBar(p),
          ],
        ),
      ),
    );
  }

  Widget _basicGroup() {
    return IosGroup(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _rowButton(
            icon: CupertinoIcons.calendar,
            label: '日期',
            value: DateFormat('yyyy年MM月dd日').format(_date),
            onTap: _pickDate,
          ),
          const IosDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('机器/工位',
                    style: TextStyle(fontSize: 13, color: kIosSecondary)),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: _machineCtrl,
                  placeholder: '如 3号机',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                if (_machines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _machines
                        .map((m) => CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFEAF2FF),
                              pressedOpacity: 0.7,
                              onPressed: () =>
                                  setState(() => _machineCtrl.text = m),
                              child: Text(m,
                                  style: const TextStyle(fontSize: 13, color: kIosBlue)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const IosDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('班次（点击直接切换）',
                    style: TextStyle(fontSize: 13, color: kIosSecondary)),
                const SizedBox(height: 8),
                if (_shifts.isEmpty)
                  const Text('请先在设置里添加班次',
                      style: TextStyle(fontSize: 13, color: kIosRed))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _shifts
                        .map((s) => _chip(
                              s.name,
                              _shift?.id == s.id,
                              () => _selectShift(s),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          const IosDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('补助比例（%）· 自己填，每个工人不一样',
                    style: TextStyle(fontSize: 13, color: kIosSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('无补助', _subsidy == 0, () => _selectSubsidy(0)),
                  ],
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  key: const ValueKey('subsidy'),
                  controller: _subsidyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '如 20 = 每件工资加20%，不填为0',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  onChanged: (v) => setState(() => _subsidy = double.tryParse(v) ?? 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowButton(
      {required IconData icon,
      required String label,
      required String value,
      required VoidCallback onTap}) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 11),
      pressedOpacity: 0.6,
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: kIosBlue),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 16, color: kIosLabel)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontSize: 16, color: kIosSecondary)),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_right, size: 16, color: kIosSecondary),
        ],
      ),
    );
  }

  Widget _lineCard(int index, _LineEdit e) {
    final lineTotal = _toLine(e)?.lineTotal ?? 0.0;
    final durSec = parseDurationSeconds(e.durationText);
    return IosGroup(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  key: ValueKey('model_$index'),
                  placeholder: '件型名称（如 A型）',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  onChanged: (v) => setState(() => e.model = v),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                onPressed: _lines.length > 1
                    ? () => setState(() => _lines.removeAt(index))
                    : null,
                child: const Icon(CupertinoIcons.trash, size: 18, color: kIosRed),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<PayMode>(
            groupValue: e.mode,
            children: {
              PayMode.perSecond: const Text('按秒'),
              PayMode.perPiece: const Text('按件'),
              PayMode.perHour: const Text('按小时'),
              PayMode.perDay: const Text('按天'),
            },
            onValueChanged: (m) => setState(() => e.mode = m ?? PayMode.perSecond),
          ),
          const SizedBox(height: 10),
          if (e.mode == PayMode.perSecond) ...[
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    key: ValueKey('dur_$index'),
                    keyboardType: TextInputType.number,
                    placeholder: '单件耗时 秒（如1080）或 分:秒',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.durationText = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: CupertinoTextField(
                    key: ValueKey('qty_$index'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '总件数',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.qtyText = v),
                  ),
                ),
              ],
            ),
            if (durSec != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    '单件 ${formatSeconds(durSec)}（${durSec}秒）· 单件工价 ¥${(_settings.ratePerSecond * durSec).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: kIosBlue)),
              ),
              if (double.tryParse(e.qtyText) != null && (double.tryParse(e.qtyText) ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '共 ${e.qtyText} 件 = ${((double.tryParse(e.qtyText) ?? 0) * durSec).round()} 秒',
                    style: const TextStyle(fontSize: 12, color: kIosSecondary)),
                ),
            ],
          ] else if (e.mode == PayMode.perPiece) ...[
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    key: ValueKey('price_$index'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '单价（元/件）',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.priceText = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: CupertinoTextField(
                    key: ValueKey('qty2_$index'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '件数',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.qtyText = v),
                  ),
                ),
              ],
            ),
          ] else if (e.mode == PayMode.perHour) ...[
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    key: ValueKey('hourly_$index'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '时薪（元/小时）',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.hourlyText = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoTextField(
                    key: ValueKey('hours_$index'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '小时数',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.hoursText = v),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    key: ValueKey('dayrate_$index'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '日薪（元/天）',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.dayRateText = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoTextField(
                    key: ValueKey('days_$index'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '天数',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    onChanged: (v) => setState(() => e.daysText = v),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
              '本行小计（含补助${_subsidy.toStringAsFixed(0)}%） ￥${(lineTotal * (1 + _subsidy / 100)).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: kIosLabel)),
          Text('基础 ￥${lineTotal.toStringAsFixed(2)} + 补助${_subsidy.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: kIosSecondary)),
        ],
      ),
    );
  }

  Widget _previewBar(({double base, double total}) p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(top: BorderSide(color: kIosSeparator, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('基础 ￥${p.base.toStringAsFixed(2)} × (1+补助${_subsidy.toStringAsFixed(0)}%) = ￥${p.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: kIosSecondary)),
                  Text('补助${_subsidy.toStringAsFixed(0)}%已计入本单金额',
                      style: const TextStyle(fontSize: 11, color: kIosGreen)),
                  Text('本单金额 ￥${p.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600, color: kIosLabel)),
                ],
              ),
            ),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              onPressed: _save,
              child: const Text('保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
