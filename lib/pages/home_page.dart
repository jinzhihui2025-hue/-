import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../data/db.dart';
import '../data/calc.dart';
import '../models/models.dart';
import '../widgets/ios_ui.dart';
import 'record_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomeData {
  final AppSettings settings;
  final List<ShiftRule> shifts;
  final List<WorkOrder> orders;
  final Map<int, List<WorkOrderLine>> lines;
  final double todayQty;
  _HomeData({
    required this.settings,
    required this.shifts,
    required this.orders,
    required this.lines,
    required this.todayQty,
  });
  double get todayTotal => orders.fold(0.0, (s, o) => s + o.totalAmount);
  double get todaySub => orders.fold(0.0, (s, o) => s + (o.totalAmount - o.baseTotal));
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final settings = await AppDb.getSettings();
    final shifts = await AppDb.getShiftRules();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final orders = await AppDb.ordersByDate(today);
    final lines = <int, List<WorkOrderLine>>{};
    double qty = 0;
    for (final o in orders) {
      final ls = await AppDb.linesOf(o.id!);
      lines[o.id!] = ls;
      for (final l in ls) {
        qty += l.quantity;
      }
    }
    return _HomeData(settings: settings, shifts: shifts, orders: orders, lines: lines, todayQty: qty);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _goRecord({WorkOrder? order, List<WorkOrderLine>? lines}) async {
    await Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => RecordPage(editOrder: order, editLines: lines),
    ));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('今日'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _refresh,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('加载失败：${snap.error}'));
            }
            final d = snap.data!;
            final shiftName = {for (final s in d.shifts) s.id: s.name};
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _summaryGroup(d),
                const IosSectionHeader('今日计件单'),
                if (d.orders.isEmpty)
                  const IosGroup(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('今天还没有记单，点击下方按钮记一笔')),
                    ),
                  )
                else
                  CupertinoListSection.insetGrouped(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    children: d.orders.map((o) => _orderTile(d, o, shiftName)).toList(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onPressed: () => _goRecord(),
                    child: const Text('记 一 笔',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryGroup(_HomeData d) {
    return IosGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日总收入（元）',
              style: TextStyle(fontSize: 13, color: kIosSecondary)),
          const SizedBox(height: 2),
          Text('￥${d.todayTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 38, fontWeight: FontWeight.w600, color: kIosLabel)),
          const SizedBox(height: 14),
          const IosDivider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _mini('今日件数', d.todayQty.toStringAsFixed(0))),
              const IosVDivider(),
              Expanded(
                  child: _mini('今日补助', '￥${d.todaySub.toStringAsFixed(2)}')),
              const IosVDivider(),
              Expanded(
                  child: _mini('秒单价', '${d.settings.ratePerSecond.toStringAsFixed(4)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kIosLabel)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: kIosSecondary)),
      ],
    );
  }

  Widget _orderTile(_HomeData d, WorkOrder o, Map<int?, String> shiftName) {
    final ls = d.lines[o.id] ?? [];
    final linesDesc = ls.map((l) {
      final m = payModeFromName(l.mode);
      if (m == PayMode.perSecond) {
        return '${l.model} ${l.quantity.toStringAsFixed(0)}件 (${formatSeconds(l.unitSeconds!.round())})';
      } else if (m == PayMode.perHour) {
        return '${l.model} ${l.hours?.toString() ?? ''}小时';
      } else if (m == PayMode.perDay) {
        return '${l.model} ${l.days?.toString() ?? ''}天';
      }
      return '${l.model} ${l.quantity.toStringAsFixed(0)}件';
    }).join('，');
    return CupertinoListTile(
      title: Text('${o.machine} · ${shiftName[o.shiftRuleId] ?? "班次"}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: Text('补助${o.subsidy.toStringAsFixed(0)}% · 基础 ￥${o.baseTotal.toStringAsFixed(2)}\n$linesDesc',
          style: const TextStyle(fontSize: 12, color: kIosSecondary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('￥${o.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kIosLabel)),
          const SizedBox(width: 2),
          const Icon(CupertinoIcons.chevron_right, size: 16, color: kIosSecondary),
        ],
      ),
      onTap: () => _goRecord(order: o, lines: ls),
    );
  }

}
