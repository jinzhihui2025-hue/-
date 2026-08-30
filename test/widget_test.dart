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

  test('订单计算: 基础×(1+补助%)', () {
    final lines = [
      WorkOrderLine(
          model: 'A型',
          mode: 'per_second',
          unitSeconds: 1124,
          quantity: 30,
          lineTotal: 0.0035 * 1124 * 30),
    ];
    // 夜班补助 20%：118.02 × 1.2 = 141.62
    final r = calcOrderTotal(lines, 20, 0.0035);
    expect(r.base, closeTo(118.02, 0.01));
    expect(r.total, closeTo(141.62, 0.01));
  });

  test('按秒工价: 1080秒 × 0.0035 × 1.2 = 4.536/件', () {
    expect(0.0035 * 1080, closeTo(3.78, 0.001));
    expect(0.0035 * 1080 * 1.2, closeTo(4.536, 0.001));
  });
}
