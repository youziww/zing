import 'package:sqflite/sqflite.dart';
import '../models/deck.dart';
import 'database_helper.dart';

class DeckDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(Deck deck) async {
    final db = await _db;
    return await db.insert('decks', deck.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Deck?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('decks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Deck.fromMap(maps.first);
  }

  Future<Deck?> getByName(String name) async {
    final db = await _db;
    final maps = await db.query('decks', where: 'name = ?', whereArgs: [name]);
    if (maps.isEmpty) return null;
    return Deck.fromMap(maps.first);
  }

  Future<List<Deck>> getAll() async {
    final db = await _db;
    final maps = await db.query('decks', orderBy: 'name ASC');
    return maps.map((m) => Deck.fromMap(m)).toList();
  }

  Future<int> update(Deck deck) async {
    final db = await _db;
    return await db.update('decks', deck.toMap(),
        where: 'id = ?', whereArgs: [deck.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return await db.delete('decks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCount() async {
    final db = await _db;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM decks'),
    ) ?? 0;
  }

  /// Get or create a deck by name (supports hierarchical names with "::").
  Future<Deck> getOrCreate(String name) async {
    final existing = await getByName(name);
    if (existing != null) return existing;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final deck = Deck(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      mod: now,
    );
    await insert(deck);
    return deck;
  }
}
