import 'package:sqflite/sqflite.dart';
import '../models/card.dart';
import 'database_helper.dart';

class CardDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(ReviewCard card) async {
    final db = await _db;
    return await db.insert('cards', card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ReviewCard?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('cards', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ReviewCard.fromMap(maps.first);
  }

  Future<List<ReviewCard>> getByNoteId(int noteId) async {
    final db = await _db;
    final maps = await db.query('cards', where: 'nid = ?', whereArgs: [noteId]);
    return maps.map((m) => ReviewCard.fromMap(m)).toList();
  }

  Future<List<ReviewCard>> getByDeckId(int deckId) async {
    final db = await _db;
    final maps = await db.query('cards', where: 'did = ?', whereArgs: [deckId]);
    return maps.map((m) => ReviewCard.fromMap(m)).toList();
  }

  Future<int> update(ReviewCard card) async {
    final db = await _db;
    return await db.update('cards', card.toMap(),
        where: 'id = ?', whereArgs: [card.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByNoteId(int noteId) async {
    final db = await _db;
    return await db.delete('cards', where: 'nid = ?', whereArgs: [noteId]);
  }

  Future<int> deleteByDeckId(int deckId) async {
    final db = await _db;
    return await db.delete('cards', where: 'did = ?', whereArgs: [deckId]);
  }

  /// Get new cards for a deck (queue=0), limited by count, ordered by due.
  Future<List<ReviewCard>> getNewCards(int deckId, int limit) async {
    final db = await _db;
    final maps = await db.query(
      'cards',
      where: 'did = ? AND queue = ?',
      whereArgs: [deckId, CardQueue.newQueue],
      orderBy: 'due ASC',
      limit: limit,
    );
    return maps.map((m) => ReviewCard.fromMap(m)).toList();
  }

  /// Get learning cards (queue=1 or queue=3) that are due.
  Future<List<ReviewCard>> getLearningCards(int deckId, int cutoff) async {
    final db = await _db;
    final maps = await db.query(
      'cards',
      where: 'did = ? AND (queue = ? OR queue = ?) AND due <= ?',
      whereArgs: [deckId, CardQueue.learning, CardQueue.relearning, cutoff],
      orderBy: 'due ASC',
    );
    return maps.map((m) => ReviewCard.fromMap(m)).toList();
  }

  /// Get review cards (queue=2) that are due today.
  Future<List<ReviewCard>> getReviewCards(int deckId, int today) async {
    final db = await _db;
    final maps = await db.query(
      'cards',
      where: 'did = ? AND queue = ? AND due <= ?',
      whereArgs: [deckId, CardQueue.review, today],
      orderBy: 'due ASC',
    );
    return maps.map((m) => ReviewCard.fromMap(m)).toList();
  }

  /// Count cards by queue type for a deck.
  Future<Map<String, int>> getCardCounts(int deckId) async {
    final db = await _db;

    final newCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM cards WHERE did = ? AND queue = ?',
      [deckId, CardQueue.newQueue],
    )) ?? 0;

    final learnCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM cards WHERE did = ? AND (queue = ? OR queue = ?)',
      [deckId, CardQueue.learning, CardQueue.relearning],
    )) ?? 0;

    final today = await _getToday();
    final reviewCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM cards WHERE did = ? AND queue = ? AND due <= ?',
      [deckId, CardQueue.review, today],
    )) ?? 0;

    return {'new': newCount, 'learn': learnCount, 'review': reviewCount};
  }

  Future<int> _getToday() async {
    final col = await _dbHelper.getCollection();
    return col.today;
  }

  /// Get total card count for a deck.
  Future<int> getCount(int deckId) async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM cards WHERE did = ?',
      [deckId],
    )) ?? 0;
  }

  /// Get all cards.
  Future<List<ReviewCard>> getAll() async {
    final db = await _db;
    final maps = await db.query('cards');
    return maps.map((m) => ReviewCard.fromMap(m)).toList();
  }

  /// Move cards to a different deck.
  Future<int> moveToDeck(List<int> cardIds, int newDeckId) async {
    final db = await _db;
    return await db.rawUpdate(
      'UPDATE cards SET did = ? WHERE id IN (${cardIds.join(",")})',
      [newDeckId],
    );
  }

  /// Count how many new cards were studied today.
  Future<int> getNewCardsStudiedToday(int deckId) async {
    final db = await _db;
    final col = await _dbHelper.getCollection();
    final dayStart = col.dayStartTimestamp * 1000; // to ms
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM revlog WHERE cid IN '
      '(SELECT id FROM cards WHERE did = ?) AND id >= ? AND type = 0',
      [deckId, dayStart],
    )) ?? 0;
  }
}
