import 'package:sqflite/sqflite.dart';
import '../models/note_type.dart';
import 'database_helper.dart';

class NoteTypeDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(NoteType noteType) async {
    final db = await _db;
    return await db.insert('notetypes', noteType.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<NoteType?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('notetypes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return NoteType.fromMap(maps.first);
  }

  Future<List<NoteType>> getAll() async {
    final db = await _db;
    final maps = await db.query('notetypes', orderBy: 'name ASC');
    return maps.map((m) => NoteType.fromMap(m)).toList();
  }

  Future<int> update(NoteType noteType) async {
    final db = await _db;
    return await db.update('notetypes', noteType.toMap(),
        where: 'id = ?', whereArgs: [noteType.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return await db.delete('notetypes', where: 'id = ?', whereArgs: [id]);
  }
}
