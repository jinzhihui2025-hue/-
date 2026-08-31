// Excel 导出 + 分享 + 导入
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/db.dart';
import '../models/models.dart';
import 'calc.dart';

Future<String?> exportExcel() async {
  final excel = Excel.createExcel();
  final sheet = excel['明细'];
  sheet.appendRow([
    TextCellValue('单号'),
    TextCellValue('日期'),
    TextCellValue('机器'),
    TextCellValue('班次'),
    TextCellValue('件型'),
    TextCellValue('方式'),
    TextCellValue('耗时(秒)'),
    TextCellValue('件数'),
    TextCellValue('单价'),
    TextCellValue('时薪'),
    TextCellValue('小时数'),
    TextCellValue('日薪'),
    TextCellValue('天数'),
    TextCellValue('行小计'),
    TextCellValue('补助%'),
    TextCellValue('本单金额'),
  ]);
  final shifts = await AppDb.getShiftRules();
  final nameById = {for (final s in shifts) s.id: s.name};
  final orders = await AppDb.ordersInRange('2020-01-01', '2099-12-31');
  for (final o in orders) {
    final lines = await AppDb.linesOf(o.id!);
    if (lines.isEmpty) {
      sheet.appendRow([
        TextCellValue(o.id.toString()),
        TextCellValue(o.date),
        TextCellValue(o.machine),
        TextCellValue(nameById[o.shiftRuleId] ?? ''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(o.subsidy),
        DoubleCellValue(o.totalAmount),
      ]);
    }
    for (final l in lines) {
      sheet.appendRow([
        TextCellValue(o.id.toString()),
        TextCellValue(o.date),
        TextCellValue(o.machine),
        TextCellValue(nameById[o.shiftRuleId] ?? ''),
        TextCellValue(l.model),
        TextCellValue(payModeLabel(payModeFromName(l.mode))),
        TextCellValue(l.unitSeconds == null ? '' : l.unitSeconds!.round().toString()),
        DoubleCellValue(l.quantity),
        DoubleCellValue(l.unitPrice ?? 0),
        DoubleCellValue(l.hourlyRate ?? 0),
        DoubleCellValue(l.hours ?? 0),
        DoubleCellValue(l.dayRate ?? 0),
        DoubleCellValue(l.days ?? 0),
        DoubleCellValue(l.lineTotal),
        DoubleCellValue(o.subsidy),
        DoubleCellValue(o.totalAmount),
      ]);
    }
  }
  final sheet2 = excel['汇总'];
  sheet2.appendRow([TextCellValue('机器'), TextCellValue('总收入(元)')]);
  final byMachine = await AppDb.groupByMachine();
  byMachine.forEach((k, v) {
    sheet2.appendRow([TextCellValue(k), DoubleCellValue(v)]);
  });
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/计件助手报表.xlsx');
  final bytes = excel.encode();
  if (bytes == null) return null;
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> shareReport(String path, Rect sharePositionOrigin) async {
  await Share.shareXFiles(
    [XFile(path)],
    text: '计件助手报表',
    sharePositionOrigin: sharePositionOrigin,
  );
}

// ---------- 导入 ----------
String _cv(Data? d) {
  if (d == null) return '';
  final v = d.value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.toString().trim();
  if (v is DoubleCellValue) return v.value.toString();
  if (v is IntCellValue) return v.value.toString();
  if (v is BoolCellValue) return v.value ? 'true' : 'false';
  return v.toString();
}

double _cd(String s) => double.tryParse(s) ?? 0;

String _fmtDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String _normDate(String s) {
  if (s.isEmpty) return '';
  final n = double.tryParse(s);
  if (n != null && n > 20000) {
    // Excel 日期序列号：1899-12-30 起的天数
    final dt = DateTime(1899, 12, 30).add(Duration(days: n.toInt()));
    return _fmtDate(dt);
  }
  var t = s.replaceAll('/', '-');
  if (t.length >= 10) return t.substring(0, 10);
  return t;
}

/// 从 Excel 导入（支持本 App 导出的文件，也支持按相同表头的其他系统表格）
/// 表头至少要有：日期、机器、件型、方式
Future<({int orders, int lines})> importExcel(String path) async {
  final bytes = await File(path).readAsBytes();
  final excel = Excel.decodeBytes(bytes);
  Sheet? sheet;
  excel.tables.forEach((name, s) {
    if (s != null && (name.contains('明细') || (sheet == null && s.rows.isNotEmpty))) {
      sheet = s;
    }
  });
  if (sheet == null) return (orders: 0, lines: 0);
  final sh = sheet!;
  final rows = sh.rows;
  if (rows.length < 2) return (orders: 0, lines: 0);
  final headers = rows.first.map((c) => _cv(c)).toList();
  int col(String name) => headers.indexWhere((h) => h.contains(name) || name.contains(h));

  final cOrder = col('单号');
  final cDate = col('日期');
  final cMachine = col('机器');
  final cShift = col('班次');
  final cModel = col('件型');
  final cMode = col('方式');
  final cSec = col('耗时');
  final cQty = col('件数');
  final cPrice = col('单价');
  final cHourly = col('时薪');
  final cHours = col('小时数');
  final cDayRate = col('日薪');
  final cDays = col('天数');
  final cSub = col('补助');
  if (cDate < 0 || cModel < 0 || cMode < 0) return (orders: 0, lines: 0);

  final settings = await AppDb.getSettings();
  final shifts = await AppDb.getShiftRules();
  Future<int> shiftId(String name) async {
    if (name.isEmpty) return shifts.isNotEmpty ? shifts.first.id! : 1;
    for (final s in shifts) {
      if (s.name == name) return s.id!;
    }
    await AppDb.insertShiftRule(ShiftRule(name: name));
    final updated = await AppDb.getShiftRules();
    return updated.firstWhere((s) => s.name == name).id!;
  }

  String? curKey;
  List<WorkOrderLine> curLines = [];
  String curDate = '', curMachine = '';
  int curShiftId = 1;
  double curSubsidy = 0;
  int orderCount = 0, lineCount = 0;

  Future<void> flush() async {
    if (curKey == null || curLines.isEmpty) return;
    final p = calcOrderTotal(curLines, curSubsidy, settings.ratePerSecond);
    final order = WorkOrder(
      date: curDate,
      machine: curMachine,
      shiftRuleId: curShiftId,
      subsidy: curSubsidy,
      baseTotal: p.base,
      totalAmount: p.total,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await AppDb.insertOrder(order, curLines);
    orderCount++;
  }

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    String s(int c) => (c >= 0 && c < row.length) ? _cv(row[c]) : '';
    final model = s(cModel);
    if (model.isEmpty) continue;
    final date = _normDate(s(cDate));
    if (date.length < 8) continue;
    final machine = s(cMachine).isEmpty ? '未填' : s(cMachine);
    final shiftName = s(cShift);
    final modeName = s(cMode);
    final mode = modeName.contains('按件')
        ? PayMode.perPiece
        : modeName.contains('按小时')
            ? PayMode.perHour
            : modeName.contains('按天')
                ? PayMode.perDay
                : PayMode.perSecond;
    final subsidy = _cd(s(cSub));
    final qty = _cd(s(cQty));
    final oid = s(cOrder);
    final key = oid.isNotEmpty ? oid : '$date|$machine|$shiftName|$subsidy|$i';
    if (curKey == null || key != curKey) {
      await flush();
      curKey = key;
      curLines = [];
      curDate = date;
      curMachine = machine;
      curSubsidy = subsidy;
      curShiftId = await shiftId(shiftName);
    }
    WorkOrderLine? line;
    if (mode == PayMode.perSecond) {
      final sec = _cd(s(cSec));
      if (sec <= 0 || qty <= 0) continue;
      line = WorkOrderLine(
          model: model,
          mode: payModeName(mode),
          unitSeconds: sec,
          quantity: qty,
          lineTotal: settings.ratePerSecond * sec * qty);
    } else if (mode == PayMode.perPiece) {
      final price = _cd(s(cPrice));
      if (price <= 0 || qty <= 0) continue;
      line = WorkOrderLine(
          model: model,
          mode: payModeName(mode),
          unitPrice: price,
          quantity: qty,
          lineTotal: price * qty);
    } else if (mode == PayMode.perHour) {
      final hr = _cd(s(cHourly));
      final hs = _cd(s(cHours));
      if (hr <= 0 || hs <= 0) continue;
      line = WorkOrderLine(
          model: model,
          mode: payModeName(mode),
          hourlyRate: hr,
          hours: hs,
          quantity: 0,
          lineTotal: hr * hs);
    } else {
      final dr = _cd(s(cDayRate));
      final ds = _cd(s(cDays));
      if (dr <= 0 || ds <= 0) continue;
      line = WorkOrderLine(
          model: model,
          mode: payModeName(mode),
          dayRate: dr,
          days: ds,
          quantity: 0,
          lineTotal: dr * ds);
    }
    curLines.add(line);
    lineCount++;
  }
  await flush();
  return (orders: orderCount, lines: lineCount);
}

// ---------- 数据备份 / 恢复（整个数据库，防丢失）----------
Future<String?> backupDb() async {
  await AppDb.close();
  try {
    final src = await AppDb.dbPath();
    final dir = await getTemporaryDirectory();
    final dst = File('${dir.path}/计件助手备份.db');
    if (await File(src).exists()) {
      await File(src).copy(dst.path);
    } else {
      return null;
    }
    return dst.path;
  } finally {
    await AppDb.db; // 重新打开
  }
}

Future<({bool ok, String msg})> restoreDb(String path) async {
  try {
    await AppDb.close();
    final dest = await AppDb.dbPath();
    if (!await File(path).exists()) return (ok: false, msg: '找不到备份文件');
    await File(path).copy(dest);
    await AppDb.db; // 重新打开
    return (ok: true, msg: '恢复成功，请重启App查看');
  } catch (e) {
    return (ok: false, msg: '恢复失败：$e');
  }
}
