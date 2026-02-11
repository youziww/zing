import 'package:sqflite/sqflite.dart';
import '../models/review_log.dart';
import 'database_helper.dart';

class ReviewDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(ReviewLog log) async {
    final db = await _db;
    return await db.insert('revlog', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReviewLog>> getByCardId(int cardId) async {
    final db = await _db;
    final maps = await db.query('revlog',
        where: 'cid = ?', whereArgs: [cardId], orderBy: 'id DESC');
    return maps.map((m) => ReviewLog.fromMap(m)).toList();
  }

  Future<List<ReviewLog>> getAll() async {
    final db = await _db;
    final maps = await db.query('revlog', orderBy: 'id DESC');
    return maps.map((m) => ReviewLog.fromMap(m)).toList();
  }

  /// Get review logs for today (since dayStartMs).
  Future<List<ReviewLog>> getToday(int dayStartMs) async {
    final db = await _db;
    final maps = await db.query(
      'revlog',
      where: 'id >= ?',
      whereArgs: [dayStartMs],
      orderBy: 'id ASC',
    );
    return maps.map((m) => ReviewLog.fromMap(m)).toList();
  }

  /// Get review logs in a date range.
  Future<List<ReviewLog>> getInRange(int startMs, int endMs) async {
    final db = await _db;
    final maps = await db.query(
      'revlog',
      where: 'id >= ? AND id < ?',
      whereArgs: [startMs, endMs],
      orderBy: 'id ASC',
    );
    return maps.map((m) => ReviewLog.fromMap(m)).toList();
  }

  /// Count reviews today.
  Future<int> countToday(int dayStartMs) async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM revlog WHERE id >= ?',
      [dayStartMs],
    )) ?? 0;
  }

  /// Get total review count.
  Future<int> getCount() async {
    final db = await _db;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM revlog'),
    ) ?? 0;
  }

  /// Delete a single review log by ID.
  Future<int> deleteById(int id) async {
    final db = await _db;
    return await db.delete('revlog', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete reviews for a card.
  Future<int> deleteByCardId(int cardId) async {
    final db = await _db;
    return await db.delete('revlog', where: 'cid = ?', whereArgs: [cardId]);
  }
}
