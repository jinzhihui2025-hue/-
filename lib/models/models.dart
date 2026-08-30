// 数据模型：设置 / 班次规则 / 件型库 / 计件单 / 明细行
enum PayMode { perSecond, perPiece, perHour, perDay }

PayMode payModeFromName(String? name) {
  switch (name) {
    case 'per_piece': return PayMode.perPiece;
    case 'per_hour': return PayMode.perHour;
    case 'per_day': return PayMode.perDay;
  }
  return PayMode.perSecond;
}

String payModeName(PayMode m) => switch (m) {
  PayMode.perSecond => 'per_second',
  PayMode.perPiece => 'per_piece',
  PayMode.perHour => 'per_hour',
  PayMode.perDay => 'per_day',
};

String payModeLabel(PayMode m) => switch (m) {
  PayMode.perSecond => '按秒',
  PayMode.perPiece => '按件',
  PayMode.perHour => '按小时',
  PayMode.perDay => '按天',
};

class AppSettings {
  final double ratePerSecond;
  final String defaultMode;
  AppSettings({this.ratePerSecond = 0.0035, this.defaultMode = 'per_second'});
  factory AppSettings.fromMap(Map<String, Object?> m) => AppSettings(
        ratePerSecond: (m['rate_per_second'] as num?)?.toDouble() ?? 0.0035,
        defaultMode: (m['default_mode'] as String?) ?? 'per_second',
      );
  Map<String, Object?> toMap() => {'rate_per_second': ratePerSecond, 'default_mode': defaultMode};
}

class ShiftRule {
  final int? id;
  final String name;
  final double defaultSubsidy; // 补助比例（%），如夜班 20 = 每件工资加 20%
  ShiftRule({this.id, required this.name, this.defaultSubsidy = 0});
  factory ShiftRule.fromMap(Map<String, Object?> m) => ShiftRule(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        defaultSubsidy: (m['default_subsidy'] as num?)?.toDouble() ?? 0,
      );
  Map<String, Object?> toMap() =>
      {'name': name, 'default_subsidy': defaultSubsidy};
}

class ModelLibItem {
  final int? id;
  final String name;
  final String mode;
  final double? unitSeconds;
  final double? unitPrice;
  final double? hourlyRate;
  final double? dayRate;
  ModelLibItem(
      {this.id,
      required this.name,
      this.mode = 'per_second',
      this.unitSeconds,
      this.unitPrice,
      this.hourlyRate,
      this.dayRate});
  factory ModelLibItem.fromMap(Map<String, Object?> m) => ModelLibItem(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        mode: (m['mode'] as String?) ?? 'per_second',
        unitSeconds: (m['unit_seconds'] as num?)?.toDouble(),
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
        hourlyRate: (m['hourly_rate'] as num?)?.toDouble(),
        dayRate: (m['day_rate'] as num?)?.toDouble(),
      );
  Map<String, Object?> toMap() => {
        'name': name,
        'mode': mode,
        'unit_seconds': unitSeconds,
        'unit_price': unitPrice,
        'hourly_rate': hourlyRate,
        'day_rate': dayRate,
      };
  String get desc {
    switch (payModeFromName(mode)) {
      case PayMode.perSecond:
        return '按秒 · ${unitSeconds?.round() ?? 0}秒/件';
      case PayMode.perPiece:
        return '按件 · ${unitPrice ?? 0}元/件';
      case PayMode.perHour:
        return '按小时 · ${hourlyRate ?? 0}元/时';
      case PayMode.perDay:
        return '按天 · ${dayRate ?? 0}元/天';
    }
  }
}

class WorkOrder {
  int? id;
  String date; // yyyy-MM-dd
  String machine;
  int shiftRuleId;
  double subsidy;
  double baseTotal;
  double totalAmount;
  int createdAt;
  WorkOrder(
      {this.id,
      required this.date,
      required this.machine,
      required this.shiftRuleId,
      this.subsidy = 0,
      this.baseTotal = 0,
      this.totalAmount = 0,
      this.createdAt = 0});
  factory WorkOrder.fromMap(Map<String, Object?> m) => WorkOrder(
        id: m['id'] as int?,
        date: (m['date'] as String?) ?? '',
        machine: (m['machine'] as String?) ?? '',
        shiftRuleId: (m['shift_rule_id'] as int?) ?? 0,
        subsidy: (m['subsidy'] as num?)?.toDouble() ?? 0,
        baseTotal: (m['base_total'] as num?)?.toDouble() ?? 0,
        totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
        createdAt: (m['created_at'] as int?) ?? 0,
      );
  Map<String, Object?> toMap() => {
        'date': date,
        'machine': machine,
        'shift_rule_id': shiftRuleId,
        'subsidy': subsidy,
        'base_total': baseTotal,
        'total_amount': totalAmount,
        'created_at': createdAt,
      };
}

class WorkOrderLine {
  int? id;
  int orderId;
  String model;
  String mode;
  double? unitSeconds;
  double? unitPrice;
  double? hourlyRate;
  double? hours;
  double? dayRate;
  double? days;
  double quantity;
  double lineTotal;
  WorkOrderLine(
      {this.id,
      this.orderId = 0,
      required this.model,
      this.mode = 'per_second',
      this.unitSeconds,
      this.unitPrice,
      this.hourlyRate,
      this.hours,
      this.dayRate,
      this.days,
      this.quantity = 0,
      this.lineTotal = 0});
  factory WorkOrderLine.fromMap(Map<String, Object?> m) => WorkOrderLine(
        id: m['id'] as int?,
        orderId: (m['order_id'] as int?) ?? 0,
        model: (m['model'] as String?) ?? '',
        mode: (m['mode'] as String?) ?? 'per_second',
        unitSeconds: (m['unit_seconds'] as num?)?.toDouble(),
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
        hourlyRate: (m['hourly_rate'] as num?)?.toDouble(),
        hours: (m['hours'] as num?)?.toDouble(),
        dayRate: (m['day_rate'] as num?)?.toDouble(),
        days: (m['days'] as num?)?.toDouble(),
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        lineTotal: (m['line_total'] as num?)?.toDouble() ?? 0,
      );
  Map<String, Object?> toMap() => {
        'order_id': orderId,
        'model': model,
        'mode': mode,
        'unit_seconds': unitSeconds,
        'unit_price': unitPrice,
        'hourly_rate': hourlyRate,
        'hours': hours,
        'day_rate': dayRate,
        'days': days,
        'quantity': quantity,
        'line_total': lineTotal,
      };
}
