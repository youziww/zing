import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../database/memory_database.dart';

/// Preloads bundled deck data into the database on web.
class PreloadService {
  static Future<void> preloadIfWeb() async {
    if (!kIsWeb) return;

    final db = await DatabaseHelper.instance.database;

    // Check if data already loaded
    final existing = await db.query('decks');
    final existingCards = await db.query('cards');
    if (existing.length > 1) return;
    if (existingCards.isNotEmpty) return;

    // Batch mode: suppress per-insert persistence during bulk load
    if (db is MemoryDatabase) db.beginBatch();

    // Load all bundled deck data files
    const assets = ['assets/n2_data.json', 'assets/biaori_data.json'];
    for (final asset in assets) {
      try {
        final jsonStr = await rootBundle.loadString(asset);
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        await _loadData(db, data);
      } catch (_) {
        // App works without preloaded data
      }
    }

    // Persist once after all data is loaded
    if (db is MemoryDatabase) db.endBatch();
  }

  static Future<void> _loadData(dynamic db, Map<String, dynamic> data) async {
    // Load notetypes
    final notetypes = data['notetypes'] as List;
    for (final nt in notetypes) {
      await db.insert('notetypes', {
        'id': nt['id'],
        'name': nt['name'],
        'flds': nt['flds'],
        'tmpls': nt['tmpls'],
        'css': nt['css'] ?? '',
        'type': nt['type'] ?? 0,
      });
    }

    // Load decks
    final decks = data['decks'] as List;
    for (final d in decks) {
      await db.insert('decks', {
        'id': d['id'],
        'name': d['name'],
        'description': d['description'] ?? '',
        'mod': d['mod'] ?? 0,
        'config': d['config'] ?? '{}',
      });
    }

    // Load notes
    final notes = data['notes'] as List;
    for (final n in notes) {
      await db.insert('notes', {
        'id': n['id'],
        'guid': n['guid'],
        'mid': n['mid'],
        'mod': n['mod'],
        'tags': n['tags'] ?? '',
        'flds': n['flds'],
        'sfld': n['sfld'],
        'csum': n['csum'] ?? 0,
      });
    }

    // Load cards
    final cards = data['cards'] as List;
    for (final c in cards) {
      await db.insert('cards', {
        'id': c['id'],
        'nid': c['nid'],
        'did': c['did'],
        'ord': c['ord'] ?? 0,
        'mod': c['mod'] ?? 0,
        'type': c['type'] ?? 0,
        'queue': c['queue'] ?? 0,
        'due': c['due'] ?? 0,
        'ivl': c['ivl'] ?? 0,
        'factor': c['factor'] ?? 2500,
        'reps': c['reps'] ?? 0,
        'lapses': c['lapses'] ?? 0,
        'left': c['left'] ?? 0,
        'odue': c['odue'] ?? 0,
        'odid': c['odid'] ?? 0,
      });
    }
  }
}
