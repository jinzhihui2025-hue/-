// Excel 导出 + 分享
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/db.dart';
import '../models/models.dart';

Future<String?> exportExcel() async {
  final excel = Excel.createExcel();
  final sheet = excel['明细'];
  sheet.appendRow([
    TextCellValue('日期'),
    TextCellValue('机器'),
    TextCellValue('班次'),
    TextCellValue('件型'),
    TextCellValue('方式'),
    TextCellValue('耗时(秒)'),
    TextCellValue('件数'),
    TextCellValue('行小计'),
    TextCellValue('补助'),
    TextCellValue('本单金额'),
  ]);
  final shifts = await AppDb.getShiftRules();
  final nameById = {for (final s in shifts) s.id: s.name};
  final orders = await AppDb.ordersInRange('2020-01-01', '2099-12-31');
  for (final o in orders) {
    final lines = await AppDb.linesOf(o.id!);
    if (lines.isEmpty) {
      sheet.appendRow([
        TextCellValue(o.date),
        TextCellValue(o.machine),
        TextCellValue(nameById[o.shiftRuleId] ?? ''),
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
        TextCellValue(o.date),
        TextCellValue(o.machine),
        TextCellValue(nameById[o.shiftRuleId] ?? ''),
        TextCellValue(l.model),
        TextCellValue(payModeLabel(payModeFromName(l.mode))),
        TextCellValue(l.unitSeconds == null ? '' : l.unitSeconds!.round().toString()),
        DoubleCellValue(l.quantity),
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
  final file = File('${dir.path}/秒薪计件报表.xlsx');
  final bytes = excel.encode();
  if (bytes == null) return null;
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> shareReport(String path) async {
  await Share.shareXFiles([XFile(path)], text: '秒薪计件报表');
}
