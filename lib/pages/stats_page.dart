import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/db.dart';
import '../widgets/ios_ui.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _loading = true;
  ({double today, double month, double all}) _sum = (today: 0, month: 0, all: 0);
  Map<String, ({double total, double sub})> _daily = {};
  Map<String, ({double total, double sub})> _dailyRange = {};
  Map<String, double> _byMachine = {};
  Map<String, double> _byShift = {};
  Map<String, double> _byMode = {};
  int _chart = 0;
  int _pieDim = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final shifts = await AppDb.getShiftRules();
    final mStart = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final mEnd = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
    final rStart = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 29)));
    final rEnd = DateFormat('yyyy-MM-dd').format(now);
    final monthOrders = await AppDb.ordersInRange(mStart, mEnd);
    final rangeOrders = await AppDb.ordersInRange(rStart, rEnd);
    final sum = await AppDb.summaryTotals();
    final byMachine = await AppDb.groupByMachine();
    final byShift = await AppDb.groupByShift(shifts);
    final byMode = await AppDb.groupByMode();
    if (!mounted) return;
    setState(() {
      _sum = sum;
      _daily = _agg(monthOrders);
      _dailyRange = _agg(rangeOrders);
      _byMachine = byMachine;
      _byShift = byShift;
      _byMode = byMode;
      _loading = false;
    });
  }

  Map<String, ({double total, double sub})> _agg(List<dynamic> orders) {
    final m = <String, ({double total, double sub})>{};
    for (final o in orders.cast<dynamic>()) {
      final date = o.date;
      final cur = m[date] ?? (total: 0.0, sub: 0.0);
      m[date] = (total: cur.total + o.totalAmount, sub: cur.sub + (o.totalAmount - o.baseTotal));
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('统计'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _sumGroup(),
                  const IosSectionHeader('图表'),
                  IosGroup(
                    child: Column(
                      children: [
                        CupertinoSlidingSegmentedControl<int>(
                          groupValue: _chart,
                          children: const {
                            0: Text('日柱状图'),
                            1: Text('趋势'),
                            2: Text('构成'),
                          },
                          onValueChanged: (v) => setState(() => _chart = v ?? 0),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(height: 250, child: _chartWidget()),
                        if (_chart == 2) ...[
                          const SizedBox(height: 12),
                          CupertinoSlidingSegmentedControl<int>(
                            groupValue: _pieDim,
                            children: const {
                              0: Text('按机器'),
                              1: Text('按班次'),
                              2: Text('按方式'),
                            },
                            onValueChanged: (v) => setState(() => _pieDim = v ?? 0),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          _chart == 0
                              ? '本月每天收入（深蓝=基础，浅蓝=补助）'
                              : _chart == 1
                                  ? '近30天收入趋势'
                                  : '按${_pieDim == 0 ? "机器" : _pieDim == 1 ? "班次" : "计价方式"}统计',
                          style: const TextStyle(fontSize: 12, color: kIosSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sumGroup() {
    return IosGroup(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: _stat('今日', _sum.today)),
          const IosVDivider(),
          Expanded(child: _stat('本月', _sum.month)),
          const IosVDivider(),
          Expanded(child: _stat('累计', _sum.all)),
        ],
      ),
    );
  }

  Widget _stat(String label, double v) {
    return Column(
      children: [
        Text('￥${v.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kIosLabel)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: kIosSecondary)),
      ],
    );
  }

  Widget _chartWidget() {
    switch (_chart) {
      case 0:
        return _barChart();
      case 1:
        return _lineChart();
      default:
        return _pieChart();
    }
  }

  Widget _barChart() {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    final prefix = DateFormat('yyyy-MM').format(now);
    double maxY = 10;
    final groups = <BarChartGroupData>[];
    for (var d = 1; d <= days; d++) {
      final ds = '$prefix-${d.toString().padLeft(2, '0')}';
      final v = _daily[ds];
      final base = v == null ? 0.0 : v.total - v.sub;
      final sub = v?.sub ?? 0.0;
      if (base + sub > maxY) maxY = base + sub;
      groups.add(BarChartGroupData(
        x: d,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: base + sub,
            color: const Color(0xFF007AFF),
            width: 12,
            rodStackItems: [
              BarChartRodStackItem(0, base, const Color(0xFF007AFF)),
              if (sub > 0)
                BarChartRodStackItem(base, base + sub, const Color(0xFF9CC9FF)),
            ],
          ),
        ],
      ));
    }
    return BarChart(BarChartData(
      maxY: maxY * 1.15,
      barGroups: groups,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xE6000000),
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
            '${group.x}日  ￥${rod.toY.toStringAsFixed(2)}',
            const TextStyle(color: CupertinoColors.white),
          ),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: kIosSecondary)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: kIosSecondary)),
          ),
        ),
      ),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _lineChart() {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (var i = 29; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final ds = DateFormat('yyyy-MM-dd').format(d);
      spots.add(FlSpot((29 - i).toDouble(), _dailyRange[ds]?.total ?? 0));
    }
    return LineChart(LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: const Color(0xFF007AFF),
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: const Color(0xFF007AFF).withValues(alpha: 0.08)),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem('￥${s.y.toStringAsFixed(2)}',
                  const TextStyle(color: CupertinoColors.white)))
              .toList(),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: kIosSecondary))),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (v, meta) => Text('${(29 - v.toInt()).toString()}天前',
                style: const TextStyle(fontSize: 9, color: kIosSecondary)),
          ),
        ),
      ),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _pieChart() {
    final data = _pieDim == 0
        ? _byMachine
        : _pieDim == 1
            ? _byShift
            : _byMode;
    const colors = [
      Color(0xFF007AFF),
      Color(0xFF34C759),
      Color(0xFFFF9500),
      Color(0xFFFF3B30),
      Color(0xFFAF52DE),
      Color(0xFF5AC8FA),
      Color(0xFFFF2D55),
      Color(0xFFA2845E),
      Color(0xFF8E8E93),
    ];
    var i = 0;
    final sections = data.entries.map((e) {
      final c = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        value: e.value,
        title: '${e.key}\n￥${e.value.toStringAsFixed(0)}',
        color: c,
        radius: 54,
        titleStyle: const TextStyle(
            fontSize: 10, color: CupertinoColors.white, fontWeight: FontWeight.w600),
      );
    }).toList();
    return sections.isEmpty
        ? const Center(child: Text('暂无数据', style: TextStyle(color: kIosSecondary)))
        : PieChart(PieChartData(
            sections: sections,
            centerSpaceRadius: 28,
            sectionsSpace: 2,
          ));
  }
}
