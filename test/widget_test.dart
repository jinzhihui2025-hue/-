import 'package:flutter_test/flutter_test.dart';
import 'package:jijian/data/calc.dart';
import 'package:jijian/models/models.dart';

void main() {
  test('秒数智能解析', () {
    expect(parseDurationSeconds('1124'), 1124);
    expect(parseDurationSeconds('18:44'), 1124);
    expect(parseDurationSeconds('1:18:44'), 4724);
    expect(parseDurationSeconds('abc'), null);
  });

  test('秒格式化', () {
    expect(formatSeconds(1124), '18:44');
    expect(formatSeconds(4724), '1:18:44');
  });

  test('订单计算: 基础×倍率+补助', () {
    final lines = [
      WorkOrderLine(
          model: 'A型',
          mode: 'per_second',
          unitSeconds: 1124,
          quantity: 30,
          lineTotal: 0.0035 * 1124 * 30),
    ];
    final r = calcOrderTotal(lines, 1.2, 20, 0.0035);
    expect(r.base, closeTo(118.02, 0.01));
    expect(r.total, closeTo(161.62, 0.01));
  });
}
