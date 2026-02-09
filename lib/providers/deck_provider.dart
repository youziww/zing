import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/deck_dao.dart';
import '../database/card_dao.dart';
import '../database/note_dao.dart';
import '../database/note_type_dao.dart';
import '../models/deck.dart';
import '../models/note.dart';
import '../models/note_type.dart';
import '../models/card.dart' as models;
import '../scheduler/deck_options.dart';
import 'package:uuid/uuid.dart';

final deckListProvider =
    AsyncNotifierProvider<DeckListNotifier, List<Deck>>(DeckListNotifier.new);

class DeckListNotifier extends AsyncNotifier<List<Deck>> {
  final _deckDao = DeckDao();
  final _cardDao = CardDao();

  @override
  Future<List<Deck>> build() async {
    return _loadDecks();
  }

  Future<List<Deck>> _loadDecks() async {
    final decks = await _deckDao.getAll();
    // Load card counts for each deck
    for (final deck in decks) {
      final counts = await _cardDao.getCardCounts(deck.id);
      deck.newCount = counts['new'] ?? 0;
      deck.learnCount = counts['learn'] ?? 0;
      deck.reviewCount = counts['review'] ?? 0;
    }
    return decks;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _loadDecks());
  }

  Future<Deck> addDeck(String name) async {
    final deck = Deck(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      mod: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await _deckDao.insert(deck);
    state = AsyncValue.data(await _loadDecks());
    return deck;
  }

  Future<void> renameDeck(int id, String newName) async {
    final deck = await _deckDao.getById(id);
    if (deck != null) {
      await _deckDao.update(deck.copyWith(
        name: newName,
        mod: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ));
      state = AsyncValue.data(await _loadDecks());
    }
  }

  Future<void> deleteDeck(int id) async {
    await _cardDao.deleteByDeckId(id);
    await _deckDao.delete(id);
    state = AsyncValue.data(await _loadDecks());
  }

  Future<DeckOptions> getDeckOptions(int deckId) async {
    final deck = await _deckDao.getById(deckId);
    if (deck != null && deck.config.isNotEmpty) {
      return DeckOptions.fromMap(deck.config);
    }
    return const DeckOptions();
  }

  Future<void> updateDeckOptions(int deckId, DeckOptions options) async {
    final deck = await _deckDao.getById(deckId);
    if (deck != null) {
      await _deckDao.update(deck.copyWith(config: options.toMap()));
    }
  }
}

final noteTypeListProvider =
    FutureProvider<List<NoteType>>((ref) async {
  final dao = NoteTypeDao();
  return await dao.getAll();
});

/// Provider for creating a new note with cards.
final noteCreatorProvider = Provider((ref) => NoteCreator());

class NoteCreator {
  final _noteDao = NoteDao();
  final _cardDao = CardDao();
  final _noteTypeDao = NoteTypeDao();
  final _uuid = const Uuid();

  Future<void> createNote({
    required int deckId,
    required int noteTypeId,
    required List<String> fields,
    String tags = '',
  }) async {
    final noteType = await _noteTypeDao.getById(noteTypeId);
    if (noteType == null) throw StateError('Note type not found');

    final now = DateTime.now().millisecondsSinceEpoch;
    final noteId = now;

    // Calculate checksum (simple hash of first field)
    final checksum = fields.isNotEmpty ? fields[0].hashCode & 0xFFFFFFFF : 0;

    final note = Note(
      id: noteId,
      guid: _uuid.v4().substring(0, 10),
      modelId: noteTypeId,
      mod: now ~/ 1000,
      tags: tags,
      fields: fields,
      checksum: checksum,
    );
    await _noteDao.insert(note);

    // Create cards based on templates
    if (noteType.isCloze) {
      // For cloze, create one card per cloze deletion
      final clozeCount = _countClozes(fields.isNotEmpty ? fields[0] : '');
      for (int i = 0; i < clozeCount; i++) {
        final card = models.ReviewCard(
          id: now + i + 1,
          noteId: noteId,
          deckId: deckId,
          ord: i,
          mod: now ~/ 1000,
        );
        await _cardDao.insert(card);
      }
      // At least one card even if no cloze found
      if (clozeCount == 0) {
        final card = models.ReviewCard(
          id: now + 1,
          noteId: noteId,
          deckId: deckId,
          ord: 0,
          mod: now ~/ 1000,
        );
        await _cardDao.insert(card);
      }
    } else {
      // Standard: one card per template
      for (int i = 0; i < noteType.templates.length; i++) {
        final card = models.ReviewCard(
          id: now + i + 1,
          noteId: noteId,
          deckId: deckId,
          ord: i,
          mod: now ~/ 1000,
        );
        await _cardDao.insert(card);
      }
    }
  }

  int _countClozes(String text) {
    final pattern = RegExp(r'\{\{c(\d+)::');
    final matches = pattern.allMatches(text);
    final nums = <int>{};
    for (final m in matches) {
      nums.add(int.parse(m.group(1)!));
    }
    return nums.length;
  }

  Future<void> updateNote({
    required int noteId,
    required List<String> fields,
    String? tags,
  }) async {
    final note = await _noteDao.getById(noteId);
    if (note == null) throw StateError('Note not found');

    final checksum = fields.isNotEmpty ? fields[0].hashCode & 0xFFFFFFFF : 0;
    await _noteDao.update(note.copyWith(
      fields: fields,
      tags: tags,
      checksum: checksum,
      mod: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
  }

  Future<void> deleteNote(int noteId) async {
    await _cardDao.deleteByNoteId(noteId);
    await _noteDao.delete(noteId);
  }
}
