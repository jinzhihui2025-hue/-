// 截图测试：真实渲染页面并输出 PNG（flutter test --update-goldens）
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jijian/main.dart';
import 'package:jijian/data/db.dart';
import 'package:jijian/data/calc.dart';
import 'package:jijian/models/models.dart';
import 'package:jijian/pages/home_page.dart';
import 'package:jijian/pages/stats_page.dart';
import 'package:jijian/pages/history_page.dart';
import 'package:jijian/pages/settings_page.dart';
import 'package:jijian/pages/record_page.dart';

Future<void> _loadCjkFont() async {
  final data = File(r'C:\Windows\Fonts\simhei.ttf').readAsBytesSync();
  final bytes = ByteData.sublistView(data);
  for (final fam in [
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
  ]) {
    final loader = FontLoader(fam)..addFont(Future.value(bytes));
    await loader.load();
  }
  // 图标字体（CupertinoIcons）
  final iconLoader = FontLoader('CupertinoIcons')
    ..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
  await iconLoader.load();
}

String _d(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

Future<void> _seed() async {
  final now = DateTime.now();
  final shifts = await AppDb.getShiftRules();
  final day = shifts.firstWhere((s) => s.name == '白班');
  final night = shifts.firstWhere((s) => s.name == '夜班');

  final l1 = [
    WorkOrderLine(model: 'A型', mode: 'per_second', unitSeconds: 1124, quantity: 30, lineTotal: 0.0035 * 1124 * 30),
  ];
  final p1 = calcOrderTotal(l1, 1.0, 0, 0.0035);
  await AppDb.insertOrder(
      WorkOrder(date: _d(now), machine: '3号机', shiftRuleId: day.id!, subsidy: 0, baseTotal: p1.base, totalAmount: p1.total),
      l1);

  final l2 = [
    WorkOrderLine(model: 'A型', mode: 'per_second', unitSeconds: 1124, quantity: 30, lineTotal: 0.0035 * 1124 * 30),
    WorkOrderLine(model: 'B型', mode: 'per_second', unitSeconds: 1500, quantity: 20, lineTotal: 0.0035 * 1500 * 20),
  ];
  final p2 = calcOrderTotal(l2, 1.2, 20, 0.0035);
  await AppDb.insertOrder(
      WorkOrder(date: _d(now), machine: '3号机', shiftRuleId: night.id!, subsidy: 20, baseTotal: p2.base, totalAmount: p2.total),
      l2);

  for (var i = 1; i <= 5; i++) {
    final dt = now.subtract(Duration(days: i));
    final qty = 20.0 + i * 5;
    final l = [
      WorkOrderLine(model: 'A型', mode: 'per_second', unitSeconds: 1124, quantity: qty, lineTotal: 0.0035 * 1124 * qty),
    ];
    final p = calcOrderTotal(l, 1.0, i.isEven ? 10 : 0, 0.0035);
    await AppDb.insertOrder(
        WorkOrder(date: _d(dt), machine: i.isEven ? '5号机' : '3号机',
            shiftRuleId: (i.isEven ? night : day).id!, subsidy: i.isEven ? 10 : 0,
            baseTotal: p.base, totalAmount: p.total),
        l);
  }
  final y = now.subtract(const Duration(days: 1));
  final l3 = [
    WorkOrderLine(model: '临时件', mode: 'per_piece', unitPrice: 3.9, quantity: 50, lineTotal: 3.9 * 50),
  ];
  final p3 = calcOrderTotal(l3, 1.0, 0, 0.0035);
  await AppDb.insertOrder(
      WorkOrder(date: _d(y), machine: '5号机', shiftRuleId: day.id!, subsidy: 0, baseTotal: p3.base, totalAmount: p3.total),
      l3);
}

Widget _wrap(Widget page) => CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      home: page,
    );

Future<void> _pumpPage(WidgetTester tester, Widget app, Finder finder, String name) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await expectLater(finder, matchesGoldenFile('screens/$name.png'));
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await _loadCjkFont();
  });

  testWidgets('capture screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() => _seed());
    debugPrint('seeded');

    await _pumpPage(tester, _wrap(const MainShell()), find.byType(MainShell), 'home');
    debugPrint('home captured');
    await _pumpPage(tester, _wrap(const MainShell(initialIndex: 1)), find.byType(MainShell), 'stats');
    debugPrint('stats captured');
    await _pumpPage(tester, _wrap(const MainShell(initialIndex: 2)), find.byType(MainShell), 'history');
    debugPrint('history captured');
    await _pumpPage(tester, _wrap(const MainShell(initialIndex: 3)), find.byType(MainShell), 'settings');
    debugPrint('settings captured');
    await _pumpPage(tester, _wrap(const RecordPage()), find.byType(RecordPage), 'record');
    debugPrint('record captured');
  });
}
