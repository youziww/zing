import 'package:sqflite/sqflite.dart';
import '../models/note.dart';
import 'database_helper.dart';

class NoteDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(Note note) async {
    final db = await _db;
    return await db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Note?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<Note?> getByGuid(String guid) async {
    final db = await _db;
    final maps = await db.query('notes', where: 'guid = ?', whereArgs: [guid]);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<List<Note>> getByModelId(int modelId) async {
    final db = await _db;
    final maps = await db.query('notes', where: 'mid = ?', whereArgs: [modelId]);
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<int> update(Note note) async {
    final db = await _db;
    return await db.update('notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getAll({int limit = 10}) async {
    final db = await _db;
    final maps = await db.query('notes', orderBy: 'mod DESC', limit: limit);
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  /// Search notes by sort field, return last 10 results.
  Future<List<Note>> search(String query, {int limit = 10}) async {
    final db = await _db;
    final maps = await db.query(
      'notes',
      where: 'sfld LIKE ? OR flds LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'mod DESC',
      limit: limit,
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  /// Get notes that belong to cards in a specific deck, return last 10.
  Future<List<Note>> getByDeckId(int deckId, {int limit = 10}) async {
    final db = await _db;
    final maps = await db.rawQuery(
      'SELECT DISTINCT n.* FROM notes n '
      'INNER JOIN cards c ON c.nid = n.id '
      'WHERE c.did = ? ORDER BY n.mod DESC LIMIT ?',
      [deckId, limit],
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  /// Delete all notes.
  Future<int> deleteAll() async {
    final db = await _db;
    return await db.delete('notes');
  }

  Future<int> getCount() async {
    final db = await _db;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM notes'),
    ) ?? 0;
  }
}
