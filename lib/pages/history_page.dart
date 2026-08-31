import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../widgets/ios_ui.dart';
import 'record_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selected = DateTime.now();
  Map<String, List<WorkOrder>> _orders = {};
  Map<String, double> _dayTotal = {};
  List<ShiftRule> _shifts = [];
  Set<String> _recordDays = {}; // 打破历史最高收入的日期

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = DateFormat('yyyy-MM-dd').format(_month);
    final end = DateFormat('yyyy-MM-dd').format(DateTime(_month.year, _month.month + 1, 0));
    final orders = await AppDb.ordersInRange(start, end);
    final byDate = <String, List<WorkOrder>>{};
    final totals = <String, double>{};
    for (final o in orders) {
      byDate.putIfAbsent(o.date, () => []).add(o);
      totals[o.date] = (totals[o.date] ?? 0) + o.totalAmount;
    }
    final shifts = await AppDb.getShiftRules();
    // 计算破纪录日期：按时间顺序，收益超过此前最高即为破纪录
    final allOrders = await AppDb.ordersInRange('2020-01-01', '2099-12-31');
    final allTotals = <String, double>{};
    for (final o in allOrders) {
      allTotals[o.date] = (allTotals[o.date] ?? 0) + o.totalAmount;
    }
    final dates = allTotals.keys.toList()..sort();
    double maxSoFar = 0;
    final rec = <String>{};
    for (final d in dates) {
      final v = allTotals[d]!;
      if (v > maxSoFar) {
        if (maxSoFar > 0) rec.add(d); // 只有超过之前的最高才算破纪录
        maxSoFar = v;
      }
    }
    if (!mounted) return;
    setState(() {
      _orders = byDate;
      _dayTotal = totals;
      _shifts = shifts;
      _recordDays = rec;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      _selected = DateTime(_month.year, _month.month, 1);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('历史'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _monthHeader(),
            _weekHeader(),
            _calendarGrid(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  Flexible(
                    child: Text(DateFormat('yyyy年MM月dd日').format(_selected),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: kIosLabel)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _recordDays.contains(DateFormat('yyyy-MM-dd').format(_selected))
                        ? '🏆 当日合计 ￥${(_dayTotal[DateFormat('yyyy-MM-dd').format(_selected)] ?? 0).toStringAsFixed(2)} · 破纪录！'
                        : '当日合计 ￥${(_dayTotal[DateFormat('yyyy-MM-dd').format(_selected)] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _recordDays.contains(DateFormat('yyyy-MM-dd').format(_selected))
                            ? const Color(0xFFE8A33D)
                            : kIosBlue),
                  ),
                ],
              ),
            ),
            const IosDivider(leftInset: 20),
            Expanded(child: _dayOrders()),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => _changeMonth(-1),
            child: const Icon(CupertinoIcons.chevron_left, color: kIosBlue, size: 20),
          ),
          Text('${_month.year}年${_month.month}月',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => _changeMonth(1),
            child: const Icon(CupertinoIcons.chevron_right, color: kIosBlue, size: 20),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFEAF2FF),
            pressedOpacity: 0.7,
            onPressed: () {
              setState(() {
                _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
                _selected = DateTime.now();
              });
              _load();
            },
            child: const Text('今天', style: TextStyle(fontSize: 13, color: kIosBlue)),
          ),
        ],
      ),
    );
  }

  Widget _weekHeader() {
    const weeks = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: weeks
            .map((w) => Expanded(
                  child: Center(
                      child: Text(w,
                          style: const TextStyle(fontSize: 12, color: kIosSecondary))),
                ))
            .toList(),
      ),
    );
  }

  Widget _calendarGrid() {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    double maxV = 1;
    for (final v in _dayTotal.values) {
      if (v > maxV) maxV = v;
    }
    final cells = <Widget>[];
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final ds = DateFormat('yyyy-MM-dd').format(date);
      final v = _dayTotal[ds] ?? 0;
      final isSel = DateFormat('yyyy-MM-dd').format(_selected) == ds;
      final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == ds;
      final isRecord = _recordDays.contains(ds);
      Color? fill;
      if (isSel) {
        fill = kIosBlue;
      } else if (v > 0) {
        fill = Color.lerp(const Color(0xFFEAF2FF), const Color(0xFF7FB8FF), (v / maxV).clamp(0.2, 1.0));
      }
      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selected = date),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: isToday && !isSel
                        ? Border.all(color: kIosBlue, width: 1.5)
                        : isRecord
                            ? Border.all(color: const Color(0xFFE8A33D), width: 1.5)
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSel || v > 0 ? FontWeight.w600 : FontWeight.w400,
                        color: isSel ? CupertinoColors.white : kIosLabel,
                      ),
                    ),
                  ),
                ),
                if (isRecord)
                  const Positioned(
                    top: -3,
                    right: -4,
                    child: Text('🏆', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: cells,
    );
  }

  Widget _dayOrders() {
    final ds = DateFormat('yyyy-MM-dd').format(_selected);
    final list = _orders[ds] ?? [];
    if (list.isEmpty) {
      return const Center(
          child: Text('当天没有记录', style: TextStyle(color: kIosSecondary)));
    }
    final shiftName = {for (final s in _shifts) s.id: s.name};
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final o = list[i];
        return CupertinoListTile(
          backgroundColor: CupertinoColors.white,
          title: Text('${o.machine} · ${shiftName[o.shiftRuleId] ?? "班次"}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          subtitle: Text('补助${o.subsidy.toStringAsFixed(0)}% · 基础 ￥${o.baseTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: kIosSecondary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('￥${o.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(CupertinoIcons.chevron_right, size: 16, color: kIosSecondary),
            ],
          ),
          onTap: () async {
            final lines = await AppDb.linesOf(o.id!);
            if (!mounted) return;
            await Navigator.of(context).push(CupertinoPageRoute(
              builder: (_) => RecordPage(editOrder: o, editLines: lines),
            ));
            _load();
          },
        );
      },
    );
  }
}
