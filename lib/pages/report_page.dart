import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../data/db.dart';
import '../widgets/ios_ui.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

typedef _Row = ({double pieces, double money});

class _ReportPageState extends State<ReportPage> {
  int _mode = 0; // 0=报表 1=工资单
  int _period = 0; // 0=日报 1=周报 2=月报 3=季报 4=年报
  DateTime _date = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = true;
  double _total = 0;
  double _pieces = 0;
  List<MapEntry<String, _Row>> _byMachine = [];
  List<MapEntry<String, _Row>> _byModel = [];

  // 工资单
  final TextEditingController _baseCtrl = TextEditingController();
  final TextEditingController _bonusCtrl = TextEditingController();
  final TextEditingController _deductCtrl = TextEditingController();
  List<dynamic> _payrollOrders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _bonusCtrl.dispose();
    _deductCtrl.dispose();
    super.dispose();
  }

  (String, String) get _range {
    switch (_period) {
      case 0:
        final s = DateFormat('yyyy-MM-dd').format(_date);
        return (s, s);
      case 1:
        final monday = _date.subtract(Duration(days: _date.weekday - 1));
        return (DateFormat('yyyy-MM-dd').format(monday),
            DateFormat('yyyy-MM-dd').format(monday.add(const Duration(days: 6))));
      case 2:
        return (DateFormat('yyyy-MM-dd').format(_month),
            DateFormat('yyyy-MM-dd').format(DateTime(_month.year, _month.month + 1, 0)));
      case 3:
        final q = (_date.month - 1) ~/ 3;
        final sM = q * 3 + 1;
        return (DateFormat('yyyy-MM-dd').format(DateTime(_date.year, sM, 1)),
            DateFormat('yyyy-MM-dd').format(DateTime(_date.year, sM + 3, 0)));
      default:
        return (DateFormat('yyyy-MM-dd').format(DateTime(_date.year, 1, 1)),
            DateFormat('yyyy-MM-dd').format(DateTime(_date.year, 12, 31)));
    }
  }

  String get _rangeLabel {
    switch (_period) {
      case 0:
        return DateFormat('yyyy年MM月dd日').format(_date);
      case 1:
        final r = _range;
        return '${r.$1.substring(5)} ~ ${r.$2.substring(5)}';
      case 2:
        return DateFormat('yyyy年MM月').format(_month);
      case 3:
        return '${_date.year}年第${(_date.month - 1) ~/ 3 + 1}季度';
      default:
        return '${_date.year}年';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (_mode == 0) {
      final r = _range;
      final orders = await AppDb.ordersInRange(r.$1, r.$2);
      double total = 0, pieces = 0;
      final byMachine = <String, _Row>{};
      final byModel = <String, _Row>{};
      for (final o in orders) {
        total += o.totalAmount;
        final factor = o.baseTotal > 0 ? o.totalAmount / o.baseTotal : 1.0;
        final lines = await AppDb.linesOf(o.id!);
        for (final l in lines) {
          if (l.quantity > 0) pieces += l.quantity;
          final m = byMachine[o.machine] ?? (pieces: 0.0, money: 0.0);
          byMachine[o.machine] =
              (pieces: m.pieces + l.quantity, money: m.money + l.lineTotal * factor);
          final md = byModel[l.model] ?? (pieces: 0.0, money: 0.0);
          byModel[l.model] =
              (pieces: md.pieces + l.quantity, money: md.money + l.lineTotal * factor);
        }
      }
      final ml = byMachine.entries.toList()
        ..sort((a, b) => b.value.money.compareTo(a.value.money));
      final mdl = byModel.entries.toList()
        ..sort((a, b) => b.value.money.compareTo(a.value.money));
      if (!mounted) return;
      setState(() {
        _total = total;
        _pieces = pieces;
        _byMachine = ml;
        _byModel = mdl;
        _loading = false;
      });
    } else {
      await _loadPayroll();
    }
  }

  Future<void> _loadPayroll() async {
    final month = DateFormat('yyyy-MM').format(_month);
    final p = await AppDb.getPayroll(month);
    final orders = await AppDb.ordersInRange('$month-01', '$month-31');
    if (!mounted) return;
    setState(() {
      _payrollOrders = orders;
      _baseCtrl.text = p.base > 0 ? p.base.toString() : '';
      _bonusCtrl.text = p.bonus > 0 ? p.bonus.toString() : '';
      _deductCtrl.text = p.deduction > 0 ? p.deduction.toString() : '';
      _loading = false;
    });
  }

  void _savePayroll() {
    final month = DateFormat('yyyy-MM').format(_month);
    AppDb.savePayroll(
      month,
      double.tryParse(_baseCtrl.text) ?? 0,
      double.tryParse(_bonusCtrl.text) ?? 0,
      double.tryParse(_deductCtrl.text) ?? 0,
    );
  }

  void _move(int dir) {
    setState(() {
      if (_mode == 1) {
        _month = DateTime(_month.year, _month.month + dir, 1);
      } else if (_period == 0) {
        _date = _date.add(Duration(days: dir));
      } else if (_period == 1) {
        _date = _date.add(Duration(days: 7 * dir));
      } else if (_period == 2) {
        _month = DateTime(_month.year, _month.month + dir, 1);
      } else if (_period == 3) {
        _date = DateTime(_date.year, _date.month + 3 * dir, 1);
      } else {
        _date = DateTime(_date.year + dir, _date.month, 1);
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('报表中心'),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _mode,
                children: const {
                  0: Text('报表'),
                  1: Text('工资单'),
                },
                onValueChanged: (v) {
                  setState(() => _mode = v ?? 0);
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : (_mode == 0 ? _reportView() : _payrollView()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportView() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        IosGroup(
          child: Column(
            children: [
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _period,
                children: const {
                  0: Text('日报'),
                  1: Text('周报'),
                  2: Text('月报'),
                  3: Text('季报'),
                  4: Text('年报'),
                },
                onValueChanged: (v) {
                  setState(() => _period = v ?? 0);
                  _load();
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => _move(-1),
                    child: const Icon(CupertinoIcons.chevron_left,
                        size: 18, color: kIosBlue),
                  ),
                  Expanded(
                    child: Text(
                      _rangeLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => _move(1),
                    child: const Icon(CupertinoIcons.chevron_right,
                        size: 18, color: kIosBlue),
                  ),
                ],
              ),
            ],
          ),
        ),
        IosGroup(
          child: Row(
            children: [
              Expanded(child: _stat('本期收益（元）', '¥${_total.toStringAsFixed(2)}')),
              const IosVDivider(),
              Expanded(child: _stat('总件数', _pieces.toStringAsFixed(0))),
            ],
          ),
        ),
        const IosSectionHeader('按机器'),
        IosGroup(
          padding: EdgeInsets.zero,
          child: _byMachine.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: Text('本期没有记录',
                          style: TextStyle(fontSize: 14, color: kIosSecondary))),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _byMachine.length; i++) ...[
                      if (i > 0) const IosDivider(leftInset: 16),
                      _row('${_byMachine[i].key}', _byMachine[i].value),
                    ],
                  ],
                ),
        ),
        const IosSectionHeader('按型号'),
        IosGroup(
          padding: EdgeInsets.zero,
          child: _byModel.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: Text('本期没有记录',
                          style: TextStyle(fontSize: 14, color: kIosSecondary))),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _byModel.length; i++) ...[
                      if (i > 0) const IosDivider(leftInset: 16),
                      _row('${_byModel[i].key}', _byModel[i].value),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _payrollView() {
    double base = 0, subsidy = 0;
    for (final o in _payrollOrders.cast<dynamic>()) {
      base += o.baseTotal;
      subsidy += o.totalAmount - o.baseTotal;
    }
    final pieceTotal = base + subsidy;
    final baseSalary = double.tryParse(_baseCtrl.text) ?? 0;
    final bonus = double.tryParse(_bonusCtrl.text) ?? 0;
    final deduct = double.tryParse(_deductCtrl.text) ?? 0;
    final payable = baseSalary + pieceTotal + bonus - deduct;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        IosGroup(
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _move(-1),
                child: const Icon(CupertinoIcons.chevron_left,
                    size: 18, color: kIosBlue),
              ),
              Expanded(
                child: Text(
                  DateFormat('yyyy年MM月').format(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _move(1),
                child: const Icon(CupertinoIcons.chevron_right,
                    size: 18, color: kIosBlue),
              ),
            ],
          ),
        ),
        const IosSectionHeader('计件收入（自动统计）'),
        IosGroup(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _payrollRow('计件提成（基础）', '¥${base.toStringAsFixed(2)}'),
              const IosDivider(),
              _payrollRow('补助', '¥${subsidy.toStringAsFixed(2)}'),
              const IosDivider(),
              _payrollRow('计件合计', '¥${pieceTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
        const IosSectionHeader('其他（自己填，自动保存）'),
        IosGroup(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _payrollInput('底薪（元/月）', _baseCtrl),
              const IosDivider(),
              _payrollInput('其他奖金（元）', _bonusCtrl),
              const IosDivider(),
              _payrollInput('扣款（元）', _deductCtrl),
            ],
          ),
        ),
        const IosSectionHeader('应发工资'),
        IosGroup(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('¥${payable.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: kIosLabel)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _payrollRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: kIosLabel)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kIosLabel)),
        ],
      ),
    );
  }

  Widget _payrollInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 15, color: kIosLabel)),
          ),
          SizedBox(
            width: 130,
            child: CupertinoTextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onChanged: (_) => _savePayroll(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: kIosLabel)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: kIosSecondary)),
      ],
    );
  }

  Widget _row(String name, _Row v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Text('${v.pieces.toStringAsFixed(0)}件',
              style: const TextStyle(fontSize: 13, color: kIosSecondary)),
          const SizedBox(width: 16),
          Text('¥${v.money.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kIosLabel)),
        ],
      ),
    );
  }
}
