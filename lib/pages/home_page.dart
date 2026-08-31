import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
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
  String _quote = '';
  String _quoteFrom = '';

  static const _localQuotes = [
    '好好休息，才有精力多赚钱。',
    '身体是赚钱的本钱，该歇就歇。',
    '今天好好干，明天更有钱。',
    '赚钱重要，身体更重要，累了就歇会儿。',
    '少熬夜，多赚钱，日子越过越好。',
    '踏实干活，钱不会辜负你。',
    '忙归忙，记得按时吃饭休息。',
    '每一分钱都是汗水的回报，加油。',
    '劳逸结合，才能细水长流地赚。',
    '干得开心，赚得安心。',
    '休息是为了走更远的路，赚更多的钱。',
    '今天辛苦了，早点休息，明天继续加油。',
    '心态好，身体好，钱包也会好。',
    '努力的人运气不会差，今天也要加油呀。',
    '赚钱的路很长，保重身体才能走到底。',
    '日子是熬出来的，钱是干出来的，稳住。',
    '不熬夜，不焦虑，稳稳当当地赚钱。',
    '睡个好觉，明天满血复活去赚钱。',
    '少想多做，钱包会越来越鼓。',
    '把活干漂亮，钱自然就来了。',
  ];

  static const _badWords = ['辛苦', '艰难', '辛酸', '累死', '残酷', '悲'];

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return '凌晨好，早点休息';
    if (h < 8) return '早上好，开工大吉';
    if (h < 11) return '上午好，加油干';
    if (h < 13) return '中午好，吃饱再干';
    if (h < 14) return '午休一下，下午更有劲';
    if (h < 18) return '下午好，继续加油';
    if (h < 23) return '晚上好，辛苦了';
    return '夜深了，早点睡，明天再战';
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    String q = _localQuotes[DateTime.now().millisecondsSinceEpoch % _localQuotes.length];
    String from = '';
    try {
      final resp = await http
          .get(Uri.parse('https://v1.hitokoto.cn/?c=i&encode=json'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final t = ((j['hitokoto'] as String?) ?? '').trim();
        final hasBad = _badWords.any((w) => t.contains(w));
        if (t.isNotEmpty && !hasBad) {
          q = t;
          from = (j['from'] as String?) ?? '';
        }
      }
    } catch (_) {
      // 网络不可用时用本地语录
    }
    if (!mounted) return;
    setState(() {
      _quote = q;
      _quoteFrom = from;
    });
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

  void _refresh() {
    setState(() => _future = _load());
    _loadQuote();
  }

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
                _greetingCard(d),
                const SizedBox(height: 6),
                _quoteCard(),
                const SizedBox(height: 6),
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

  String get _greetingEmoji {
    final h = DateTime.now().hour;
    if (h < 5) return '🌙';
    if (h < 8) return '🌅';
    if (h < 11) return '☀️';
    if (h < 13) return '🍚';
    if (h < 14) return '😴';
    if (h < 18) return '💪';
    if (h < 23) return '🌆';
    return '🌙';
  }

  Widget _greetingCard(_HomeData d) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFF8FBFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(_greetingEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_greeting,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kIosLabel)),
          ),
          Text(DateFormat('M月d日 EEEE').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, color: kIosSecondary)),
        ],
      ),
    );
  }

  Widget _quoteCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7E8), Color(0xFFFFFBF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3E3C8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(CupertinoIcons.quote_bubble_fill,
                  size: 16, color: Color(0xFFE8A33D)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _quote.isEmpty ? '加载中…' : '“$_quote”',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5A4632)),
                ),
              ),
            ],
          ),
          if (_quoteFrom.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('—— $_quoteFrom',
                    style: const TextStyle(fontSize: 11, color: kIosSecondary)),
              ),
            ),
        ],
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
