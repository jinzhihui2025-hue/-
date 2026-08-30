// 计算引擎：秒数智能解析 + 行小计 + 订单金额（基础×倍率+补助）
import '../models/models.dart';

/// 智能解析时长输入：
///  "1124" -> 1124 秒；"18:44" -> 1124 秒；"1:18:44" -> 4724 秒
int? parseDurationSeconds(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  if (s.contains(':')) {
    final parts = s.split(':').map((p) => int.tryParse(p.trim())).toList();
    if (parts.any((p) => p == null)) return null;
    final nums = parts.cast<int>();
    if (nums.length == 2) return nums[0] * 60 + nums[1];
    if (nums.length == 3) return nums[0] * 3600 + nums[1] * 60 + nums[2];
    return null;
  }
  final n = int.tryParse(s);
  if (n == null || n < 0) return null;
  return n;
}

/// 秒 -> "18:44" / "1:18:44"
String formatSeconds(int sec) {
  if (sec < 0) sec = 0;
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// 单行小计
double calcLineTotal(WorkOrderLine l, double ratePerSecond) {
  switch (payModeFromName(l.mode)) {
    case PayMode.perSecond:
      return (ratePerSecond * (l.unitSeconds ?? 0)) * l.quantity;
    case PayMode.perPiece:
      return (l.unitPrice ?? 0) * l.quantity;
    case PayMode.perHour:
      return (l.hourlyRate ?? 0) * (l.hours ?? 0);
    case PayMode.perDay:
      return (l.dayRate ?? 0) * (l.days ?? 0);
  }
}

/// 订单：基础合计 + 最终金额（基础 × (1 + 补助百分比/100)）
({double base, double total}) calcOrderTotal(
    List<WorkOrderLine> lines, double subsidyPercent, double ratePerSecond) {
  var base = 0.0;
  for (final l in lines) {
    base += calcLineTotal(l, ratePerSecond);
  }
  return (base: base, total: base * (1 + subsidyPercent / 100));
}
