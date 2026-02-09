import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive.dart';

import '../database/card_dao.dart';
import '../database/note_dao.dart';
import '../database/deck_dao.dart';
import '../database/note_type_dao.dart';
import '../models/card.dart';
import '../models/note.dart';
import '../models/deck.dart';
import '../models/note_type.dart';

/// Service for importing .apkg files.
class ImportService {
  final CardDao _cardDao = CardDao();
  final NoteDao _noteDao = NoteDao();
  final DeckDao _deckDao = DeckDao();
  final NoteTypeDao _noteTypeDao = NoteTypeDao();

  /// Import an .apkg file. Returns the number of notes imported.
  Future<ImportResult> importApkg(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    // .apkg is a ZIP file
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find the SQLite database file
    ArchiveFile? dbFile;
    Map<String, String> mediaMap = {};

    for (final archiveFile in archive) {
      if (archiveFile.name == 'collection.anki2' ||
          archiveFile.name == 'collection.anki21') {
        dbFile = archiveFile;
      } else if (archiveFile.name == 'media') {
        // Media mapping JSON
        final content = utf8.decode(archiveFile.content as List<int>);
        mediaMap = Map<String, String>.from(jsonDecode(content) as Map);
      }
    }

    if (dbFile == null) {
      throw FormatException('Invalid .apkg file: no collection database found');
    }

    // Write the SQLite DB to a temp file
    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(tempDir.path, 'import_temp.db');
    final tempFile = File(tempDbPath);
    await tempFile.writeAsBytes(dbFile.content as List<int>);

    try {
      // Open the imported database
      final importDb = await openDatabase(tempDbPath, readOnly: true);

      int notesImported = 0;
      int cardsImported = 0;

      try {
        // Import decks and models from col table
        await _importDecksAndModels(importDb);

        // Import notes
        notesImported = await _importNotes(importDb);

        // Import cards
        cardsImported = await _importCards(importDb);

        // Import media files
        await _importMedia(archive, mediaMap);
      } finally {
        await importDb.close();
      }

      return ImportResult(
        notesImported: notesImported,
        cardsImported: cardsImported,
      );
    } finally {
      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _importDecksAndModels(Database importDb) async {
    // Try reading from col table (Anki 2.0/2.1 format)
    try {
      final colRows = await importDb.query('col');
      if (colRows.isNotEmpty) {
        final row = colRows.first;

        // Import decks
        final decksJson = row['decks'] as String?;
        if (decksJson != null) {
          final decksMap = jsonDecode(decksJson) as Map<String, dynamic>;
          for (final entry in decksMap.entries) {
            final deckData = entry.value as Map<String, dynamic>;
            final deck = Deck(
              id: int.parse(entry.key),
              name: deckData['name'] as String? ?? 'Imported',
              mod: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
            await _deckDao.insert(deck);
          }
        }

        // Import models (note types)
        final modelsJson = row['models'] as String?;
        if (modelsJson != null) {
          final modelsMap = jsonDecode(modelsJson) as Map<String, dynamic>;
          for (final entry in modelsMap.entries) {
            final modelData = entry.value as Map<String, dynamic>;
            final fields = (modelData['flds'] as List?)
                    ?.map((f) => FieldDef.fromMap(f as Map<String, dynamic>))
                    .toList() ??
                [];
            final templates = (modelData['tmpls'] as List?)
                    ?.map(
                        (t) => CardTemplate.fromMap(t as Map<String, dynamic>))
                    .toList() ??
                [];

            final noteType = NoteType(
              id: int.parse(entry.key),
              name: modelData['name'] as String? ?? 'Imported',
              fields: fields,
              templates: templates,
              css: modelData['css'] as String? ?? '',
              type: modelData['type'] as int? ?? 0,
            );
            await _noteTypeDao.insert(noteType);
          }
        }
      }
    } catch (_) {
      // Newer Anki format may store decks/models differently
      // Try importing from separate tables
      try {
        final deckRows = await importDb.query('decks');
        for (final row in deckRows) {
          await _deckDao.insert(Deck.fromMap(row));
        }
      } catch (_) {}

      try {
        final modelRows = await importDb.query('notetypes');
        for (final row in modelRows) {
          await _noteTypeDao.insert(NoteType.fromMap(row));
        }
      } catch (_) {}
    }
  }

  Future<int> _importNotes(Database importDb) async {
    int count = 0;
    final noteRows = await importDb.query('notes');
    for (final row in noteRows) {
      final note = Note.fromMap(row);
      await _noteDao.insert(note);
      count++;
    }
    return count;
  }

  Future<int> _importCards(Database importDb) async {
    int count = 0;
    final cardRows = await importDb.query('cards');
    for (final row in cardRows) {
      final card = ReviewCard.fromMap(row);
      await _cardDao.insert(card);
      count++;
    }
    return count;
  }

  Future<void> _importMedia(
      Archive archive, Map<String, String> mediaMap) async {
    if (mediaMap.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    for (final entry in mediaMap.entries) {
      final archiveIndex = entry.key;
      final filename = entry.value;

      // Find the file in the archive
      try {
        final archiveFile = archive.findFile(archiveIndex);
        if (archiveFile != null) {
          final outFile = File(p.join(mediaDir.path, filename));
          await outFile.writeAsBytes(archiveFile.content as List<int>);
        }
      } catch (_) {
        // Skip files that can't be extracted
      }
    }
  }
}

class ImportResult {
  final int notesImported;
  final int cardsImported;

  ImportResult({required this.notesImported, required this.cardsImported});
}
