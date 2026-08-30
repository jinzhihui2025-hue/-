// SQLite 数据层：建表、种子数据、CRUD、聚合查询
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class AppDb {
  static Database? _db;
  static Future<Database> get db async => _db ??= await _open();

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'miaoxin.db');
    return openDatabase(path, version: 2, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE settings(id INTEGER PRIMARY KEY, rate_per_second REAL, default_mode TEXT)');
      await db.execute(
          'CREATE TABLE shift_rule(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, multiplier REAL, default_subsidy REAL)');
      await db.execute(
          'CREATE TABLE model_lib(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, mode TEXT, unit_seconds REAL, unit_price REAL, hourly_rate REAL, day_rate REAL)');
      await db.execute(
          'CREATE TABLE work_order(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, machine TEXT, shift_rule_id INTEGER, subsidy REAL, base_total REAL, total_amount REAL, created_at INTEGER)');
      await db.execute(
          'CREATE TABLE work_order_line(id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER, model TEXT, mode TEXT, unit_seconds REAL, unit_price REAL, hourly_rate REAL, hours REAL, day_rate REAL, days REAL, quantity REAL, line_total REAL)');
      await db.insert(
          'settings', {'id': 1, 'rate_per_second': 0.0035, 'default_mode': 'per_second'});
      await db.insert('shift_rule', {'name': '白班', 'multiplier': 1.0, 'default_subsidy': 0});
      await db.insert('shift_rule', {'name': '夜班', 'multiplier': 1.2, 'default_subsidy': 20});
    }, onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) {
        await db.execute('ALTER TABLE work_order_line ADD COLUMN day_rate REAL');
        await db.execute('ALTER TABLE work_order_line ADD COLUMN days REAL');
        await db.execute('ALTER TABLE model_lib ADD COLUMN day_rate REAL');
      }
    });
  }

  // ---------- 设置 ----------
  static Future<AppSettings> getSettings() async {
    final d = await db;
    final rows = await d.query('settings', limit: 1);
    if (rows.isEmpty) return AppSettings();
    return AppSettings.fromMap(rows.first);
  }

  static Future<void> saveSettings(AppSettings s) async {
    final d = await db;
    await d.insert('settings', {'id': 1, ...s.toMap()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- 班次规则 ----------
  static Future<List<ShiftRule>> getShiftRules() async {
    final d = await db;
    final rows = await d.query('shift_rule', orderBy: 'id ASC');
    return rows.map(ShiftRule.fromMap).toList();
  }

  static Future<void> insertShiftRule(ShiftRule r) async =>
      (await db).insert('shift_rule', r.toMap());
  static Future<void> updateShiftRule(ShiftRule r) async =>
      (await db).update('shift_rule', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  static Future<void> deleteShiftRule(int id) async =>
      (await db).delete('shift_rule', where: 'id = ?', whereArgs: [id]);

  // ---------- 件型库 ----------
  static Future<List<ModelLibItem>> getModelLib() async {
    final d = await db;
    final rows = await d.query('model_lib', orderBy: 'name ASC');
    return rows.map(ModelLibItem.fromMap).toList();
  }

  static Future<void> insertModelLib(ModelLibItem m) async =>
      (await db).insert('model_lib', m.toMap());
  static Future<void> updateModelLib(ModelLibItem m) async =>
      (await db).update('model_lib', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  static Future<void> deleteModelLib(int id) async =>
      (await db).delete('model_lib', where: 'id = ?', whereArgs: [id]);

  // ---------- 计件单 ----------
  static Future<int> insertOrder(WorkOrder order, List<WorkOrderLine> lines) async {
    final d = await db;
    final id = await d.insert('work_order', order.toMap());
    for (final l in lines) {
      l.orderId = id;
      await d.insert('work_order_line', l.toMap());
    }
    return id;
  }

  static Future<void> updateOrder(WorkOrder order, List<WorkOrderLine> lines) async {
    final d = await db;
    await d.update('work_order', order.toMap(), where: 'id = ?', whereArgs: [order.id]);
    await d.delete('work_order_line', where: 'order_id = ?', whereArgs: [order.id]);
    for (final l in lines) {
      l.orderId = order.id!;
      await d.insert('work_order_line', l.toMap());
    }
  }

  static Future<void> deleteOrder(int id) async {
    final d = await db;
    await d.delete('work_order_line', where: 'order_id = ?', whereArgs: [id]);
    await d.delete('work_order', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<WorkOrder>> ordersByDate(String date) async {
    final d = await db;
    final rows = await d.query('work_order',
        where: 'date = ?', whereArgs: [date], orderBy: 'id DESC');
    return rows.map(WorkOrder.fromMap).toList();
  }

  static Future<List<WorkOrder>> ordersInRange(String start, String end) async {
    final d = await db;
    final rows = await d.query('work_order',
        where: 'date >= ? AND date <= ?', whereArgs: [start, end],
        orderBy: 'date ASC, id ASC');
    return rows.map(WorkOrder.fromMap).toList();
  }

  static Future<List<WorkOrderLine>> linesOf(int orderId) async {
    final d = await db;
    final rows = await d.query('work_order_line',
        where: 'order_id = ?', whereArgs: [orderId], orderBy: 'id ASC');
    return rows.map(WorkOrderLine.fromMap).toList();
  }

  static Future<List<String>> distinctMachines() async {
    final d = await db;
    final rows = await d
        .query('work_order', columns: ['machine'], distinct: true, orderBy: 'machine ASC');
    return rows.map((r) => (r['machine'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
  }

  // ---------- 聚合（图表用）----------
  /// 某月每天的 [总收入, 补助部分]；key = 'yyyy-MM-dd'
  static Future<Map<String, ({double total, double sub})>> dailyTotalsOfMonth(
      String monthPrefix) async {
    final orders = await ordersInRange('$monthPrefix-01', '$monthPrefix-31');
    final map = <String, ({double total, double sub})>{};
    for (final o in orders) {
      final sub = o.totalAmount - o.baseTotal;
      final cur = map[o.date] ?? (total: 0.0, sub: 0.0);
      map[o.date] = (total: cur.total + o.totalAmount, sub: cur.sub + sub);
    }
    return map;
  }

  /// 按机器分组
  static Future<Map<String, double>> groupByMachine() async {
    final d = await db;
    final rows = await d.query('work_order');
    final map = <String, double>{};
    for (final r in rows) {
      final m = (r['machine'] as String?) ?? '未填';
      map[m] = (map[m] ?? 0) + ((r['total_amount'] as num?)?.toDouble() ?? 0);
    }
    return map;
  }

  /// 按班次分组
  static Future<Map<String, double>> groupByShift(List<ShiftRule> shifts) async {
    final d = await db;
    final rows = await d.query('work_order');
    final nameById = {for (final s in shifts) s.id: s.name};
    final map = <String, double>{};
    for (final r in rows) {
      final name = nameById[(r['shift_rule_id'] as int?)] ?? '其他';
      map[name] = (map[name] ?? 0) + ((r['total_amount'] as num?)?.toDouble() ?? 0);
    }
    return map;
  }

  /// 按计价方式分组（按基础贡献比例分摊倍率与补助）
  static Future<Map<String, double>> groupByMode() async {
    final d = await db;
    final rows = await d.query('work_order');
    final map = <String, double>{};
    for (final r in rows) {
      final oid = r['id'] as int;
      final base = (r['base_total'] as num?)?.toDouble() ?? 0;
      final total = (r['total_amount'] as num?)?.toDouble() ?? 0;
      final factor = base > 0 ? total / base : 1.0;
      final lines = await linesOf(oid);
      for (final l in lines) {
        final key = payModeLabel(payModeFromName(l.mode));
        map[key] = (map[key] ?? 0) + (l.lineTotal * factor);
      }
    }
    return map;
  }

  /// 今日 / 本月 / 累计 收入
  static Future<({double today, double month, double all})> summaryTotals() async {
    final d = await db;
    final rows = await d.query('work_order');
    final now = DateTime.now();
    final todayStr = _d(now);
    final monthPrefix = todayStr.substring(0, 7);
    double today = 0, month = 0, all = 0;
    for (final r in rows) {
      final t = (r['total_amount'] as num?)?.toDouble() ?? 0;
      final date = (r['date'] as String?) ?? '';
      all += t;
      if (date.startsWith(monthPrefix)) month += t;
      if (date == todayStr) today += t;
    }
    return (today: today, month: month, all: all);
  }

  static String _d(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
