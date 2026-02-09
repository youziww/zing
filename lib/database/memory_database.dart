import 'package:sqflite/sqflite.dart';

/// A minimal in-memory Database implementation for web preview.
/// Does not parse SQL - uses table-based Map storage.
class MemoryDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  bool _isOpen = true;
  int _lastInsertId = 0;

  @override
  String get path => ':memory:';

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _isOpen = true;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    // Just track table creation, ignore indexes etc
    final createMatch = RegExp(r'CREATE\s+TABLE\s+(\w+)', caseSensitive: false)
        .firstMatch(sql);
    if (createMatch != null) {
      final table = createMatch.group(1)!;
      _tables.putIfAbsent(table, () => []);
    }
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    _tables.putIfAbsent(table, () => []);
    final rows = _tables[table]!;

    if (conflictAlgorithm == ConflictAlgorithm.replace && values.containsKey('id')) {
      rows.removeWhere((r) => r['id'] == values['id']);
    }

    rows.add(Map<String, dynamic>.from(values));
    _lastInsertId = values['id'] as int? ?? ++_lastInsertId;
    return _lastInsertId;
  }

  @override
  Future<List<Map<String, dynamic>>> query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
    var rows = List<Map<String, dynamic>>.from(_tables[table] ?? []);

    if (where != null && whereArgs != null) {
      rows = _applyWhere(rows, where, whereArgs);
    }

    if (orderBy != null) {
      rows = _applyOrderBy(rows, orderBy);
    }

    if (limit != null) {
      rows = rows.take(limit).toList();
    }

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<int> update(String table, Map<String, dynamic> values,
      {String? where,
      List<Object?>? whereArgs,
      ConflictAlgorithm? conflictAlgorithm}) async {
    final rows = _tables[table] ?? [];
    int count = 0;

    for (int i = 0; i < rows.length; i++) {
      if (where == null || _matchesWhere(rows[i], where, whereArgs ?? [])) {
        for (final entry in values.entries) {
          rows[i][entry.key] = entry.value;
        }
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> delete(String table,
      {String? where, List<Object?>? whereArgs}) async {
    final rows = _tables[table] ?? [];
    final before = rows.length;

    if (where != null) {
      rows.removeWhere((r) => _matchesWhere(r, where, whereArgs ?? []));
    } else {
      rows.clear();
    }
    return before - rows.length;
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object?>? arguments]) async {
    // Handle COUNT(*) queries
    final countMatch = RegExp(
            r'SELECT\s+COUNT\(\*\)\s+FROM\s+(\w+)(?:\s+WHERE\s+(.+))?',
            caseSensitive: false)
        .firstMatch(sql);
    if (countMatch != null) {
      final table = countMatch.group(1)!;
      var rows = List<Map<String, dynamic>>.from(_tables[table] ?? []);
      final whereClause = countMatch.group(2);
      if (whereClause != null && arguments != null) {
        rows = _applyWhere(rows, whereClause, arguments);
      }
      return [{'COUNT(*)': rows.length}];
    }

    // Handle JOIN queries (for note_dao.getByDeckId)
    final joinMatch = RegExp(
            r'SELECT\s+DISTINCT\s+n\.\*\s+FROM\s+notes\s+n\s+INNER\s+JOIN\s+cards\s+c\s+ON\s+c\.nid\s*=\s*n\.id\s+WHERE\s+c\.did\s*=\s*\?',
            caseSensitive: false)
        .firstMatch(sql);
    if (joinMatch != null && arguments != null && arguments.isNotEmpty) {
      final deckId = arguments[0];
      final cards = _tables['cards'] ?? [];
      final notes = _tables['notes'] ?? [];
      final noteIds = cards
          .where((c) => c['did'] == deckId)
          .map((c) => c['nid'])
          .toSet();
      return notes
          .where((n) => noteIds.contains(n['id']))
          .map((n) => Map<String, dynamic>.from(n))
          .toList();
    }

    // Handle revlog queries with cid IN subquery
    final revlogMatch = RegExp(
            r'SELECT\s+COUNT\(\*\)\s+FROM\s+revlog\s+WHERE\s+cid\s+IN\s+\(SELECT\s+id\s+FROM\s+cards\s+WHERE\s+did\s*=\s*\?\)\s+AND\s+id\s*>=\s*\?\s+AND\s+type\s*=\s*0',
            caseSensitive: false)
        .firstMatch(sql);
    if (revlogMatch != null && arguments != null && arguments.length >= 2) {
      final deckId = arguments[0];
      final sinceId = arguments[1] as int;
      final cards = _tables['cards'] ?? [];
      final revlog = _tables['revlog'] ?? [];
      final cardIds = cards
          .where((c) => c['did'] == deckId)
          .map((c) => c['id'])
          .toSet();
      final count = revlog
          .where((r) =>
              cardIds.contains(r['cid']) &&
              (r['id'] as int) >= sinceId &&
              r['type'] == 0)
          .length;
      return [{'COUNT(*)': count}];
    }

    return [];
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    // Handle UPDATE ... WHERE id IN (...)
    final updateMatch = RegExp(
            r'UPDATE\s+(\w+)\s+SET\s+(\w+)\s*=\s*\?\s+WHERE\s+id\s+IN\s+\(([^)]+)\)',
            caseSensitive: false)
        .firstMatch(sql);
    if (updateMatch != null && arguments != null && arguments.isNotEmpty) {
      final table = updateMatch.group(1)!;
      final col = updateMatch.group(2)!;
      final idsStr = updateMatch.group(3)!;
      final ids = idsStr.split(',').map((s) => int.parse(s.trim())).toSet();
      final rows = _tables[table] ?? [];
      int count = 0;
      for (final row in rows) {
        if (ids.contains(row['id'])) {
          row[col] = arguments[0];
          count++;
        }
      }
      return count;
    }
    return 0;
  }

  // --- WHERE clause matching ---

  List<Map<String, dynamic>> _applyWhere(
      List<Map<String, dynamic>> rows, String where, List<Object?> args) {
    return rows.where((r) => _matchesWhere(r, where, args)).toList();
  }

  bool _matchesWhere(
      Map<String, dynamic> row, String where, List<Object?> args) {
    // Parse simple conditions joined by AND/OR
    // Support: col = ?, col <= ?, col >= ?, col < ?, col > ?
    // Support: col LIKE ?, (col = ? OR col = ?)
    var argIndex = 0;

    // Flatten parentheses for simple OR groups
    var cleaned = where.replaceAll('(', '').replaceAll(')', '');

    final orParts = cleaned.split(RegExp(r'\s+OR\s+', caseSensitive: false));
    if (orParts.length > 1 &&
        !cleaned.contains(RegExp(r'\s+AND\s+', caseSensitive: false))) {
      // Pure OR expression
      for (final part in orParts) {
        final condArgStart = argIndex;
        final condArgCount = '?'.allMatches(part).length;
        if (_evalCondition(
            row, part.trim(), args.sublist(condArgStart, condArgStart + condArgCount))) {
          return true;
        }
        argIndex += condArgCount;
      }
      return false;
    }

    // AND expressions (possibly with OR sub-groups)
    final andParts = cleaned.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    for (final part in andParts) {
      final condArgCount = '?'.allMatches(part).length;
      final subArgs = args.sublist(argIndex, argIndex + condArgCount);
      argIndex += condArgCount;

      // Check OR within this AND part
      final subOrParts = part.split(RegExp(r'\s+OR\s+', caseSensitive: false));
      if (subOrParts.length > 1) {
        bool anyMatch = false;
        var subArgIdx = 0;
        for (final orPart in subOrParts) {
          final cnt = '?'.allMatches(orPart).length;
          if (_evalCondition(
              row, orPart.trim(), subArgs.sublist(subArgIdx, subArgIdx + cnt))) {
            anyMatch = true;
          }
          subArgIdx += cnt;
        }
        if (!anyMatch) return false;
      } else {
        if (!_evalCondition(row, part.trim(), subArgs)) return false;
      }
    }
    return true;
  }

  bool _evalCondition(
      Map<String, dynamic> row, String cond, List<Object?> args) {
    // col = ?
    var m = RegExp(r'(\w+)\s*=\s*\?').firstMatch(cond);
    if (m != null) return row[m.group(1)] == args[0];

    // col <= ?
    m = RegExp(r'(\w+)\s*<=\s*\?').firstMatch(cond);
    if (m != null) {
      final v = row[m.group(1)];
      return v is num && args[0] is num && v <= (args[0] as num);
    }

    // col >= ?
    m = RegExp(r'(\w+)\s*>=\s*\?').firstMatch(cond);
    if (m != null) {
      final v = row[m.group(1)];
      return v is num && args[0] is num && v >= (args[0] as num);
    }

    // col < ?
    m = RegExp(r'(\w+)\s*<\s*\?').firstMatch(cond);
    if (m != null) {
      final v = row[m.group(1)];
      return v is num && args[0] is num && v < (args[0] as num);
    }

    // col LIKE ?
    m = RegExp(r'(\w+)\s+LIKE\s+\?', caseSensitive: false).firstMatch(cond);
    if (m != null) {
      final v = row[m.group(1)]?.toString() ?? '';
      final pattern = (args[0] as String)
          .replaceAll('%', '.*')
          .replaceAll('_', '.');
      return RegExp(pattern, caseSensitive: false).hasMatch(v);
    }

    return true; // unknown condition, pass through
  }

  List<Map<String, dynamic>> _applyOrderBy(
      List<Map<String, dynamic>> rows, String orderBy) {
    final match =
        RegExp(r'(\w+)\s*(ASC|DESC)?', caseSensitive: false).firstMatch(orderBy);
    if (match == null) return rows;

    final col = match.group(1)!;
    final desc = match.group(2)?.toUpperCase() == 'DESC';

    rows.sort((a, b) {
      final va = a[col];
      final vb = b[col];
      if (va == null && vb == null) return 0;
      if (va == null) return desc ? 1 : -1;
      if (vb == null) return desc ? -1 : 1;
      final cmp = Comparable.compare(va as Comparable, vb as Comparable);
      return desc ? -cmp : cmp;
    });
    return rows;
  }

  // --- Unused interface members ---

  @override
  Batch batch() => throw UnimplementedError();

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      throw UnimplementedError();

  @override
  Future<T> devInvokeSqlMethod<T>(String method, String sql,
          [List<Object?>? arguments]) =>
      throw UnimplementedError();

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action,
          {bool? exclusive}) =>
      throw UnimplementedError();

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      throw UnimplementedError();

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async =>
      rawUpdate(sql, arguments);

  @override
  Database get database => this;

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action,
          {bool? exclusive}) =>
      throw UnimplementedError();

  @override
  Future<QueryCursor> queryCursor(String table,
          {bool? distinct,
          List<String>? columns,
          String? where,
          List<Object?>? whereArgs,
          String? groupBy,
          String? having,
          String? orderBy,
          int? limit,
          int? offset,
          int? bufferSize}) =>
      throw UnimplementedError();

  @override
  Future<QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments,
          {int? bufferSize}) =>
      throw UnimplementedError();
}
