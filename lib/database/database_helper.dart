import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_type.dart';
import '../models/deck.dart';
import '../models/collection.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('zing.db');
    return _database!;
  }

  Future<Database> _initDB(String filename) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filename);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// For testing: initialize with a specific database instance.
  void setDatabase(Database db) {
    _database = db;
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE col (
        id INTEGER PRIMARY KEY,
        crt INTEGER NOT NULL,
        mod INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY,
        guid TEXT UNIQUE NOT NULL,
        mid INTEGER NOT NULL,
        mod INTEGER NOT NULL,
        tags TEXT NOT NULL DEFAULT '',
        flds TEXT NOT NULL,
        sfld TEXT NOT NULL,
        csum INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY,
        nid INTEGER NOT NULL,
        did INTEGER NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0,
        mod INTEGER NOT NULL DEFAULT 0,
        type INTEGER NOT NULL DEFAULT 0,
        queue INTEGER NOT NULL DEFAULT 0,
        due INTEGER NOT NULL DEFAULT 0,
        ivl INTEGER NOT NULL DEFAULT 0,
        factor INTEGER NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        left INTEGER NOT NULL DEFAULT 0,
        odue INTEGER NOT NULL DEFAULT 0,
        odid INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (nid) REFERENCES notes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE revlog (
        id INTEGER PRIMARY KEY,
        cid INTEGER NOT NULL,
        ease INTEGER NOT NULL,
        ivl INTEGER NOT NULL DEFAULT 0,
        lastIvl INTEGER NOT NULL DEFAULT 0,
        factor INTEGER NOT NULL DEFAULT 0,
        time INTEGER NOT NULL DEFAULT 0,
        type INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE decks (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        mod INTEGER NOT NULL DEFAULT 0,
        config TEXT NOT NULL DEFAULT '{}'
      )
    ''');

    await db.execute('''
      CREATE TABLE notetypes (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        flds TEXT NOT NULL,
        tmpls TEXT NOT NULL,
        css TEXT NOT NULL DEFAULT '',
        type INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_cards_nid ON cards(nid)');
    await db.execute('CREATE INDEX idx_cards_did ON cards(did)');
    await db.execute('CREATE INDEX idx_cards_queue ON cards(queue)');
    await db.execute('CREATE INDEX idx_cards_due ON cards(due)');
    await db.execute('CREATE INDEX idx_notes_mid ON notes(mid)');
    await db.execute('CREATE INDEX idx_revlog_cid ON revlog(cid)');

    // Initialize collection metadata
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Set creation time to start of today (4am cutoff like Anki)
    final crt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 4)
        .millisecondsSinceEpoch ~/ 1000;
    final col = Collection(crt: crt, mod: now);
    await db.insert('col', col.toMap());

    // Create default deck
    final defaultDeck = Deck(
      id: 1,
      name: 'Default',
      mod: now,
    );
    await db.insert('decks', defaultDeck.toMap());

    // Create default note types
    final basicType = NoteType.basic(DateTime.now().millisecondsSinceEpoch);
    await db.insert('notetypes', basicType.toMap());

    final basicReversedType = NoteType.basicReversed(
      DateTime.now().millisecondsSinceEpoch + 1,
    );
    await db.insert('notetypes', basicReversedType.toMap());

    final clozeType = NoteType.cloze(
      DateTime.now().millisecondsSinceEpoch + 2,
    );
    await db.insert('notetypes', clozeType.toMap());
  }

  Future<Collection> getCollection() async {
    final db = await database;
    final maps = await db.query('col', limit: 1);
    if (maps.isEmpty) {
      throw StateError('Collection not initialized');
    }
    return Collection.fromMap(maps.first);
  }

  Future<void> updateCollectionMod() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('col', {'mod': now});
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
