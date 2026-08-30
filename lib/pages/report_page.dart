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
  int _period = 0; // 0=日报 1=周报 2=月报 3=季报 4=年报
  DateTime _date = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = true;
  double _total = 0;
  double _pieces = 0;
  List<MapEntry<String, _Row>> _byMachine = [];
  List<MapEntry<String, _Row>> _byModel = [];

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
  }

  void _move(int dir) {
    setState(() {
      if (_period == 0) {
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
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
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
                        Expanded(
                          child: _stat('本期收益（元）', '¥${_total.toStringAsFixed(2)}'),
                        ),
                        const IosVDivider(),
                        Expanded(
                          child: _stat('总件数', _pieces.toStringAsFixed(0)),
                        ),
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
                                _row('${_byMachine[i].key}',
                                    _byMachine[i].value),
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
              ),
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
